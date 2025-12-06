import nodemailer from 'nodemailer';

// Create a transporter object using the SMTP settings
const transporter=nodemailer.createTransport({
        host:'localhost',
        service:'gmail',
        port:587,
        secure:false,
        auth:{
            user:process.env.EMAIL,
            pass:process.env.EMAIL_PASSWORD
        }
    })

// Export the transporter
export default transporter;