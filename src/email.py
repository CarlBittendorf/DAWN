from email.message import EmailMessage
import smtplib, pathlib

def send_email(server, login, password, sender, receivers, subject, html, filenames = []) -> None:
    images = []

    for i, filename in enumerate(filenames):
        with open(filename, "rb") as image:
            data = image.read()
        
        extension = pathlib.Path(filename).suffix[1:]
        images.append({
            "name": str(i),
            "data": data,
            "cid": str(i),
            "extension": extension
        })

    # create an EmailMessage object
    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = sender
    message["To"] = receivers
    message.set_content(html, subtype="html")

    for image in images:
        message.add_related(image["data"], "image", image["extension"], cid=f'<{image["cid"]}>')

    # send the email
    with smtplib.SMTP(server, 587) as server:
        server.starttls()
        server.login(login, password)
        server.sendmail(sender, receivers, message.as_string())