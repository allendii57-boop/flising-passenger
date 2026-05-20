const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

const getTransporter = () => {
  const config = functions.config().email;
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user: config.user, pass: config.pass },
  });
};

exports.onVerificationStatusChange = functions.firestore
  .document("users/{uid}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.verificationStatus === after.verificationStatus) return null;
    const newStatus = after.verificationStatus;
    if (newStatus !== "verified" && newStatus !== "rejected") return null;
    const userEmail = after.email;
    const userName = after.name || "there";
    if (!userEmail) return null;
    const subject = newStatus === "verified"
      ? "Welcome to Flising! You're verified ✅"
      : "Flising — Action required on your documents";
    const htmlBody = newStatus === "verified"
      ? `<h2>Welcome ${userName}!</h2><p>You are now verified. Open the app and request your first ride!</p>`
      : `<h2>Hi ${userName},</h2><p>Your documents could not be verified. Please resubmit in the app.</p>`;
    try {
      await getTransporter().sendMail({
        from: `"Flising" <${functions.config().email.user}>`,
        to: userEmail, subject, html: htmlBody,
      });
    } catch (err) {
      console.error("Email error:", err);
    }
    return null;
  });
