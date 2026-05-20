const { onValueUpdated } = require("firebase-functions/v2/database");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

const emailUser = defineSecret("EMAIL_USER");
const emailPass = defineSecret("EMAIL_PASS");

exports.onVerificationStatusChange = onValueUpdated(
  {
    ref: "/users/passengers/{uid}",
    instance: "flising-default-rtdb",
    region: "asia-southeast1",
    secrets: [emailUser, emailPass],
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
        user: emailUser.value(),
        pass: emailPass.value(),
      },
    });

    await transporter.sendMail({
      from: `"Flising" <${emailUser.value()}>`,
      to: userEmail,
      subject: "Welcome to Flising! You're verified ✅",
      html: `
        <div style="font-family:sans-serif;max-width:500px;margin:auto">
          <h2 style="color:#E9692C">Welcome to Flising, ${userName}! 🎉</h2>
          <p>Your documents have been verified. You can now request rides!</p>
          <p>Open the Flising app and book your first ride.</p>
          <br/>
          <p style="color:#888;font-size:12px">The Flising Team</p>
        </div>
      `,
    });
    return null;
  }
);
