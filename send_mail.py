import sys
import asyncio
import os
from email.message import EmailMessage

import aiosmtplib
from dotenv import load_dotenv

# Load .env file
load_dotenv()

SUBJECT = sys.argv[1]
BODY = sys.argv[2]

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))

SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")

TO_EMAIL = os.getenv("TO_EMAIL")


async def send_email():
    if not all([
        SMTP_HOST,
        SMTP_USER,
        SMTP_PASSWORD,
        TO_EMAIL
    ]):
        raise ValueError("Missing required SMTP environment variables")

    msg = EmailMessage()
    msg["From"] = SMTP_USER
    msg["To"] = TO_EMAIL
    msg["Subject"] = SUBJECT

    msg.set_content(BODY)

    await aiosmtplib.send(
        msg,
        hostname=SMTP_HOST,
        port=SMTP_PORT,
        start_tls=True,
        username=SMTP_USER,
        password=SMTP_PASSWORD
    )


if __name__ == "__main__":
    asyncio.run(send_email())
