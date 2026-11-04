/**
 * Get the departure time in epoch milliseconds.
 * Prefers expiresAt (minus the expiry buffer) as it is a timezone-independent
 * timestamp created on the client side. Falls back to parsing departureTime string.
 */
const { emailToKey, keyToEmail } = require('./emailKey');

const EXPIRY_BUFFER_MS = 15 * 60 * 1000; // 15 minutes buffer added on ride creation

function getDepartureTimeEpoch(ride) {
  if (ride.expiresAt) {
    return ride.expiresAt - EXPIRY_BUFFER_MS;
  }
  if (!ride.departureTime) return null;
  try {
    const match = ride.departureTime.match(/^(\d+)\/(\d+)\/(\d+)\s+at\s+(.+)$/i);
    if (!match) return null;
    const [_, day, month, year, timeStr] = match;
    const timeMatch = timeStr.trim().match(/^(\d+):(\d+)(?:\s*(AM|PM))?$/i);
    if (!timeMatch) return null;
    let [__, hour, minute, ampm] = timeMatch;
    hour = parseInt(hour, 10);
    minute = parseInt(minute, 10);
    if (ampm) {
      if (ampm.toUpperCase() === 'PM' && hour < 12) {
        hour += 12;
      } else if (ampm.toUpperCase() === 'AM' && hour === 12) {
        hour = 0;
      }
    }
    const dt = new Date(parseInt(year, 10), parseInt(month, 10) - 1, parseInt(day, 10), hour, minute);
    return dt.getTime();
  } catch (e) {
    return null;
  }
}

/**
 * Get rider detail from riderDetails — works with both Mongoose Maps
 * (from .findById()) and plain objects (from .lean()).
 */
function getRiderDetail(ride, name) {
  if (!ride.riderDetails) return null;
  const safeName = emailToKey(name);
  if (typeof ride.riderDetails.get === 'function') {
    return ride.riderDetails.get(safeName) || null;
  }
  return ride.riderDetails[safeName] || ride.riderDetails[name] || null;
}

/**
 * Core sweep-line capacity check.
 * @param {Array<string>} existingNames - names whose allocations count as occupied
 * @param {Object} ride - ride document (lean or Mongoose)
 * @param {number} newStartIndex
 * @param {number} newEndIndex
 * @param {number} requestedSeats
 * @returns {boolean} true if the new allocation fits
 */
function _checkCapacityWith(existingNames, ride, newStartIndex, newEndIndex, requestedSeats) {
  // Exclude kicked and dropped passengers — they no longer occupy seats
  const kickedSet = new Set(ride.kicked || []);
  const droppedSet = new Set(ride.droppedPassengers || []);

  const changes = [];

  for (const pName of existingNames) {
    if (kickedSet.has(pName) || droppedSet.has(pName)) continue;
    const p = getRiderDetail(ride, pName);
    if (p) {
      changes.push({ index: p.startIndex, change: p.seats });
      changes.push({ index: p.endIndex, change: -p.seats });
    }
  }

  changes.push({ index: newStartIndex, change: requestedSeats });
  changes.push({ index: newEndIndex, change: -requestedSeats });

  // Sort by index first; at the same index, process drop-offs (negative)
  // BEFORE pickups (positive).  This way, if passenger A drops off at the
  // same point where passenger B boards, the seat is freed first and B can
  // use it without exceeding capacity.
  changes.sort((a, b) => a.index - b.index || a.change - b.change);

  let current = 0;
  let peak = 0;
  for (const c of changes) {
    current += c.change;
    if (current > peak) peak = current;
  }

  return peak <= ride.totalSeats;
}

/**
 * For SEARCH results: only count accepted passengers.
 * Rides stay visible until the driver actually accepts enough passengers
 * to fill the segment.
 */
function checkCapacityForSearch(ride, newStartIndex, newEndIndex, requestedSeats) {
  return _checkCapacityWith(ride.passengers || [], ride, newStartIndex, newEndIndex, requestedSeats);
}

/**
 * For REQUESTS: check capacity differently based on route preference.
 * The user requested to only apply the fix (ignoring pending requests) to 'shared_start'.
 * For 'flexible' and others, keep the old behavior of counting pending requests.
 */
function checkCapacityForRequest(ride, newStartIndex, newEndIndex, requestedSeats) {
  // Only count accepted passengers so multiple requests can be made, regardless of route preference
  return _checkCapacityWith(ride.passengers || [], ride, newStartIndex, newEndIndex, requestedSeats);
}

/**
 * Legacy wrapper — used by accept endpoint to re-check remaining requests.
 * Counts only accepted passengers (the just-accepted one is already in passengers).
 */
function checkCapacity(ride, newStartIndex, newEndIndex, requestedSeats) {
  return _checkCapacityWith(ride.passengers || [], ride, newStartIndex, newEndIndex, requestedSeats);
}

/**
 * Decodes riderDetails map keys (_dot_ back to .) for a lean object before emitting over sockets.
 */
function decodeRiderDetailsForSocket(rideObj) {
  // Mongoose schema toJSON hook ALREADY decodes the keys.
  // We must not double-decode them, otherwise Buffer.from('email@foo.com', 'base64url') 
  // produces garbage output like 'm⵭,ڞ	W('
  return rideObj;
}

/**
 * Build the view of a ride that a given viewer is allowed to see.
 *
 * - The driver (ride.riderEmail) sees every passenger's pickup/drop details,
 *   because they need them to plan the route.
 * - A passenger or requester sees only their own pickup/drop details; other
 *   riders are reduced to name, seats and paid status.
 * - Anyone else (search results, the global search room) sees no per-rider
 *   location data and no chat history.
 *
 * Pass `{ isAdmin: true }` to skip filtering for the admin panel.
 */
function viewRideFor(rideObj, viewerEmail, { isAdmin = false } = {}) {
  if (!rideObj || typeof rideObj !== 'object') return rideObj;
  if (isAdmin) return rideObj;

  const viewer = viewerEmail ? String(viewerEmail).trim().toLowerCase() : '';
  const isDriver = viewer !== '' && viewer === rideObj.riderEmail;
  const view = { ...rideObj };

  if (view.riderDetails && typeof view.riderDetails === 'object') {
    const filtered = {};
    for (const [email, details] of Object.entries(view.riderDetails)) {
      if (isDriver || email === viewer || !details) {
        filtered[email] = details;
      } else {
        filtered[email] = { riderName: details.riderName, paid: details.paid, seats: details.seats };
      }
    }
    view.riderDetails = filtered;
  }

  const inList = (list) => Array.isArray(list) && viewer !== '' && list.includes(viewer);
  const isParticipant = isDriver || inList(view.passengers) || inList(view.boardedPassengers) || inList(view.droppedPassengers);
  if (!isParticipant) delete view.chatMessages;

  return view;
}

/** Same as viewRideFor; kept for existing call sites. */
function sanitizeRideForBroadcast(rideObj, viewerEmail) {
  return viewRideFor(rideObj, viewerEmail);
}

/** True when the user takes part in the ride as driver, passenger or requester. */
function isRideMember(ride, email) {
  if (!ride || !email) return false;
  const e = String(email).trim().toLowerCase();
  return ride.riderEmail === e ||
    (ride.passengers || []).includes(e) ||
    (ride.boardedPassengers || []).includes(e) ||
    (ride.droppedPassengers || []).includes(e) ||
    (ride.requests || []).includes(e);
}

/** Validate a lat/lng pair coming from a client. Returns {lat, lng} or null. */
function parseCoords(lat, lng) {
  const la = Number(lat);
  const ln = Number(lng);
  if (!Number.isFinite(la) || !Number.isFinite(ln)) return null;
  if (la < -90 || la > 90 || ln < -180 || ln > 180) return null;
  return { lat: la, lng: ln };
}

module.exports = {
  getDepartureTimeEpoch,
  getRiderDetail,
  _checkCapacityWith,
  checkCapacityForSearch,
  checkCapacityForRequest,
  checkCapacity,
  decodeRiderDetailsForSocket,
  sanitizeRideForBroadcast,
  viewRideFor,
  isRideMember,
  parseCoords
};
