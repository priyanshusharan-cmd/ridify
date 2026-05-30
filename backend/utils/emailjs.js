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
        'Content-Type': 'application/json'
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
    throw error;
  }
};

module.exports = {
  sendOtpEmail
};
