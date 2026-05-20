const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

exports.onVerificationStatusChange = functions.firestore.onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.verificationStatus === after.verificationStatus) return null;
    const newStatus = after.verificationStatus;
    if (newStatus !== "verified" && newStatus !== "rejected") return null;
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

    const subject = newStatus === "verified"
      ? "Welcome to Flising! You're verified ✅"
      : "Flising — Action required on your documents";
    const html = newStatus === "verified"
      ? `<h2>Welcome ${userName}!</h2><p>You are now verified. Open the app and request your first ride!</p>`
      : `<h2>Hi ${userName},</h2><p>Your documents could not be verified. Please resubmit in the app.</p>`;

    await transporter.sendMail({
      from: `"Flising" <${process.env.EMAIL_USER}>`,
      to: userEmail, subject, html,
    });
    return null;
  }
);
