/**
 * Get the departure time in epoch milliseconds.
 * Prefers expiresAt (minus the expiry buffer) as it is a timezone-independent
 * timestamp created on the client side. Falls back to parsing departureTime string.
 */
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
  const safeName = name.replace(/\./g, '_dot_');
  if (typeof ride.riderDetails.get === 'function') {
    return ride.riderDetails.get(safeName) || null;
  }
  return ride.riderDetails[safeName] || null;
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

module.exports = {
  getDepartureTimeEpoch,
  getRiderDetail,
  _checkCapacityWith,
  checkCapacityForSearch,
  checkCapacityForRequest,
  checkCapacity
};
