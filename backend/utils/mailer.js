const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

/**
 * Send an email.
 * @param {Object} opts
 * @param {string}   opts.to      - recipient address
 * @param {string}   opts.subject - email subject
 * @param {string}   opts.html    - HTML body
 */
async function sendMail({ to, subject, html }) {
  if (!process.env.EMAIL_USER || process.env.EMAIL_USER.includes('your_gmail')) {
    console.warn('[mailer] EMAIL_USER not configured — skipping email send.');
    return;
  }
  const info = await transporter.sendMail({
    from: `"${process.env.EMAIL_FROM_NAME || 'Route4Life'}" <${process.env.EMAIL_USER}>`,
    to,
    subject,
    html,
  });
  console.log('[mailer] Message sent:', info.messageId);
}

module.exports = sendMail;
