from email.message import EmailMessage
import smtplib

def send_email(server, login, password, sender, receivers, subject, html) -> None:
    # create an EmailMessage object
    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = sender
    message["To"] = receivers
    message.set_content(html, subtype="html")

    # send the email
    with smtplib.SMTP(server, 587) as server:
        server.starttls()
        server.login(login, password)
        server.sendmail(sender, receivers, message.as_string())