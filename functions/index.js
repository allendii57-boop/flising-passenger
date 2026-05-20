const { onValueUpdated } = require("firebase-functions/v2/database");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

exports.onVerificationStatusChange = onValueUpdated(
  {
    ref: "/users/passengers/{uid}",
    instance: "flising-default-rtdb",
    region: "asia-southeast1",
  },
  async (event) => {
    const before = event.data.before.val();
    const after = event.data.after.val();
    if (before.isVerified === after.isVerified) return null;
    if (!after.isVerified) return null;

    const userEmail = after.email;
    const userName = after.name || "there";
    if (!userEmail) return null;

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });

    await transporter.sendMail({
      from: `"Flising" <${process.env.EMAIL_USER}>`,
      to: userEmail,
      subject: "Welcome to Flising! You're verified ✅",
      html: `<h2>Welcome ${userName}!</h2><p>You are now verified. Open the app and request your first ride!</p>`,
    });
    return null;
  }
);
