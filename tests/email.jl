include("../src/main.jl")

title = "Test Message"
html = make_html(
    title,
    [
        make_title(title),
        make_paragraph("This is a test.")
    ]
)

send_email(EMAIL_CREDENTIALS, EMAIL_ERROR_RECEIVER, title, html)