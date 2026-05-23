const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
admin.initializeApp();

// ============================================
// EMAIL TRANSPORTER (Gmail)
// ============================================
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'yourflising@gmail.com',      // CHANGE THIS
    pass: 'xxxx xxxx xxxx xxxx'         // CHANGE THIS (App Password)
  }
});

// ============================================
// 1. WELCOME EMAIL — triggers on new user
// ============================================
exports.sendWelcomeEmail = functions.auth.user().onCreate((user) => {
  return transporter.sendMail({
    from: 'Flising <yourflising@gmail.com>',
    to: user.email,
    subject: '🚗 Welcome to Flising!',
    html: `
      <div style="font-family:Arial;max-width:500px;margin:auto">
        <h2 style="color:#E9692C">Welcome to Flising!</h2>
        <p>Hi ${user.displayName || 'there'},</p>
        <p>Your account has been created successfully.</p>
        <p>Please verify your email then complete your profile verification to start booking rides.</p>
        <br/>
        <p style="color:#888">— The Flising Team</p>
      </div>
    `
  });
});

// ============================================
// 2. APPROVAL EMAIL — triggers when admin
//    sets isVerified: true in database
// ============================================
exports.sendApprovalEmail = functions.database
  .ref('users/passengers/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.val();
    const after = change.after.val();

    // Only fire when isVerified flips from false to true
    if (!before.isVerified && after.isVerified) {
      const email = after.email;
      const name = after.name || 'Passenger';

      return transporter.sendMail({
        from: 'Flising <yourflising@gmail.com>',
        to: email,
        subject: '✅ You are now verified on Flising!',
        html: `
          <div style="font-family:Arial;max-width:500px;margin:auto">
            <h2 style="color:#4CAF50">You're Verified!</h2>
            <p>Hi ${name},</p>
            <p>Your account has been reviewed and approved.</p>
            <p>You can now open the Flising app and request rides!</p>
            <br/>
            <p style="color:#888">— The Flising Team</p>
          </div>
        `
      });
    }
    return null;
  });

// ============================================
// 3. PUSH NOTIFICATION — new ride to driver
// ============================================
exports.notifyDriverNewRide = functions.database
  .ref('rides/{rideId}')
  .onCreate(async (snap, context) => {
    const ride = snap.val();
    const driverId = ride.assignedDriverId;
    if (!driverId) return null;

    // Get driver's FCM token
    const driverSnap = await admin.database()
      .ref(`drivers/${driverId}/fcmToken`)
      .get();

    if (!driverSnap.exists()) return null;
    const fcmToken = driverSnap.val();

    const message = {
      token: fcmToken,
      notification: {
        title: '🚗 New Ride Request!',
        body: `Pickup: ${ride.pickupText} → ${ride.dropoffText}`,
      },
      data: {
        rideId: context.params.rideId,
        type: 'NEW_RIDE',
      },
      android: {
        priority: 'high',
        notification: { sound: 'default' }
      }
    };

    return admin.messaging().send(message);
  });

// ============================================
// 4. PUSH NOTIFICATION — ride accepted to passenger
// ============================================
exports.notifyPassengerRideAccepted = functions.database
  .ref('rides/{rideId}/status')
  .onUpdate(async (change, context) => {
    const before = change.before.val();
    const after = change.after.val();

    if (before !== 'ACCEPTED' && after === 'ACCEPTED') {
      const rideSnap = await admin.database()
        .ref(`rides/${context.params.rideId}`)
        .get();
      const ride = rideSnap.val();

      const passengerSnap = await admin.database()
        .ref(`users/passengers/${ride.passengerId}/fcmToken`)
        .get();

      if (!passengerSnap.exists()) return null;

      return admin.messaging().send({
        token: passengerSnap.val(),
        notification: {
          title: '✅ Driver is on the way!',
          body: 'Your ride has been accepted. Track your driver on the map.',
        },
        data: { rideId: context.params.rideId, type: 'RIDE_ACCEPTED' },
        android: { priority: 'high', notification: { sound: 'default' } }
      });
    }
    return null;
  });
