const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'controllers', 'rideController.js');
let code = fs.readFileSync(filePath, 'utf-8');

// 1. Imports
if (!code.includes('emailKey')) {
  code = code.replace(
    `const { isValidEmail, isValidObjectId } = require('../utils/validators');`,
    `const { isValidEmail, isValidObjectId } = require('../utils/validators');\nconst { emailToKey, keyToEmail } = require('../utils/emailKey');\nconst asyncHandler = require('../utils/asyncHandler');`
  );
}

// 2. Base64 replace
code = code.replace(/key\.replace\(\/_dot_\/g, '\.'\)/g, 'keyToEmail(key)');

// Replace specific assignment patterns for replace(/\./g, '_dot_')
code = code.replace(/const safeEmail = riderEmail\.replace\(\/\\\.\/g, '_dot_'\);/g, 'const safeEmail = emailToKey(riderEmail);');
code = code.replace(/const safeName = req\.params\.riderName\.replace\(\/\\\.\/g, '_dot_'\);/g, 'const safeName = emailToKey(req.params.riderName);');
code = code.replace(/const safeName = passengerEmail\.replace\(\/\\\.\/g, '_dot_'\);/g, 'const safeName = emailToKey(passengerEmail);');
code = code.replace(/const safeName = pName\.replace\(\/\\\.\/g, '_dot_'\);/g, 'const safeName = emailToKey(pName);');

// 3. getDriverStats
const statsCode = `
exports.getDriverStats = async (req, res) => {
  try {
    const driverEmail = req.user.email;
    const stats = await Ride.aggregate([
      { $match: { riderEmail: driverEmail, status: 'completed' } },
      {
        $group: {
          _id: null,
          totalRides: { $sum: 1 },
          totalDistanceKm: { $sum: '$totalDistance' },
          totalDurationMs: {
            $sum: {
              $cond: [
                { $and: ['$startedAt', '$completedAt'] },
                { $subtract: ['$completedAt', '$startedAt'] },
                0
              ]
            }
          }
        }
      }
    ]);
    const result = stats[0] || { totalRides: 0, totalDistanceKm: 0, totalDurationMs: 0 };
    res.json({
      totalRides: result.totalRides,
      totalDistanceKm: Math.round(result.totalDistanceKm),
      totalOnlineTimeMins: Math.floor(result.totalDurationMs / 60000),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
`;
if (!code.includes('getDriverStats')) {
  code += statsCode;
}

// 4. acceptRider optimistic lock
const acceptOriginal = `    await ride.save();
    const rideId = ride._id.toString();
    req.io.to(rideId).emit('ride_accepted', { rideId, ride: ride.toJSON() });
    res.status(200).json(ride);`;

const acceptNew = `    const updateResult = await Ride.findOneAndUpdate(
      {
        _id: ride._id,
        optimisticLock: ride.optimisticLock,
        requests: passengerEmail
      },
      {
        $set: {
          status: ride.status,
          passengers: ride.passengers,
          requests: ride.requests,
          declined: ride.declined,
          riderDetails: ride.riderDetails,
        },
        $inc: { optimisticLock: 1 }
      },
      { new: true }
    );

    if (!updateResult) {
      return res.status(409).json({
        error: 'Concurrent modification detected. The ride state changed. Please retry.',
        code: 'OPTIMISTIC_LOCK_CONFLICT'
      });
    }

    const rideId = updateResult._id.toString();
    req.io.to(rideId).emit('ride_accepted', { rideId, ride: updateResult.toJSON() });
    res.status(200).json(updateResult);`;

// To ensure we only target acceptRider's save:
if (code.includes('exports.acceptRider =')) {
  let parts = code.split('exports.declineRider =');
  parts[0] = parts[0].replace(acceptOriginal, acceptNew);
  code = parts.join('exports.declineRider =');
}

// 5. requestRide optimistic lock
const requestOriginal = `    await ride.save();

    const rideId = ride._id.toString();
    req.joinUserToRide(riderEmail, rideId);
    req.io.to(rideId).emit('new_ride_request', { rideId, ride: ride.toJSON() });

    res.status(200).json({ success: true });`;

const requestNew = `    const updateResult = await Ride.findOneAndUpdate(
      { _id: ride._id, optimisticLock: ride.optimisticLock },
      {
        $set: {
          requests: ride.requests,
          riderDetails: ride.riderDetails
        },
        $inc: { optimisticLock: 1 }
      },
      { new: true }
    );

    if (!updateResult) {
      return res.status(409).json({
        error: 'Concurrent modification detected. Please retry.',
        code: 'OPTIMISTIC_LOCK_CONFLICT'
      });
    }

    const rideId = updateResult._id.toString();
    req.joinUserToRide(riderEmail, rideId);
    req.io.to(rideId).emit('new_ride_request', { rideId, ride: updateResult.toJSON() });

    res.status(200).json({ success: true });`;

if (code.includes('exports.requestRide =')) {
  let parts = code.split('exports.acceptRider =');
  parts[0] = parts[0].replace(requestOriginal, requestNew);
  code = parts.join('exports.acceptRider =');
}

// 6. Wrap exports with asyncHandler
const wrapCode = `
// Wrap all controllers with asyncHandler
Object.keys(exports).forEach(key => {
  if (typeof exports[key] === 'function') {
    exports[key] = asyncHandler(exports[key]);
  }
});
`;
if (!code.includes('Object.keys(exports).forEach')) {
  code += wrapCode;
}

fs.writeFileSync(filePath, code);
console.log('Successfully updated rideController.js with optimistic locks, base64 keys, stats, and asyncHandlers.');
