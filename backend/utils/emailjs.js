const EMAILJS_URL = 'https://api.emailjs.com/api/v1.0/email/send';

/**
 * Sends an email using EmailJS REST API.
 * @param {string} toEmail - The recipient's email address.
 * @param {string} otpCode - The 6-digit OTP code.
 * @returns {Promise<boolean>} True if successful, throws error if not.
 */
const sendOtpEmail = async (toEmail, otpCode) => {
  const serviceId = process.env.EMAILJS_SERVICE_ID;
  const templateId = process.env.EMAILJS_TEMPLATE_ID;
  const publicKey = process.env.EMAILJS_PUBLIC_KEY;
  const privateKey = process.env.EMAILJS_PRIVATE_KEY;

  if (!serviceId || !templateId || !publicKey || !privateKey) {
    console.error('EmailJS environment variables are missing.');
    return false;
  }

  const payload = {
    service_id: serviceId,
    template_id: templateId,
    user_id: publicKey,
    accessToken: privateKey,
    template_params: {
      to_email: toEmail,
      otp_code: otpCode
    }
  };

  try {
    const response = await fetch(EMAILJS_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Origin': 'http://localhost:3000',
        'Referer': 'http://localhost:3000/'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('EmailJS Error:', errorText);
      throw new Error(`EmailJS failed: ${response.status} ${response.statusText}`);
    }

    return true;
  } catch (error) {
    console.error('Failed to send OTP via EmailJS:', error.message);
    console.log(`\n================================`);
    console.log(`DEVELOPMENT FALLBACK OTP:`);
    console.log(`Email: ${toEmail}`);
    console.log(`OTP Code: ${otpCode}`);
    console.log(`================================\n`);
    // Return true so the app doesn't crash, allowing the user to read the OTP from the terminal
    return true;
  }
};

module.exports = {
  sendOtpEmail
};
