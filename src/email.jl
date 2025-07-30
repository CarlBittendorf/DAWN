
const CSS = """
@import url("https://fonts.googleapis.com/css2?family=Roboto:ital,wght@0,100..900;1,100..900&display=swap");

@media screen and (max-width: 600px) {
  .content {
    width: 100% !important;
    display: block !important;
  }
  .main,
  .footer {
    padding: 40px !important;
  }
}

@media all {
  .ExternalClass {
    width: 100%;
  }

  .ExternalClass,
  .ExternalClass p,
  .ExternalClass span,
  .ExternalClass font,
  .ExternalClass td,
  .ExternalClass div {
    line-height: 100%;
  }

  .apple-link a {
    color: inherit !important;
    font-family: inherit !important;
    font-size: inherit !important;
    font-weight: inherit !important;
    line-height: inherit !important;
    text-decoration: none !important;
  }

  #MessageViewBody a {
    color: inherit;
    text-decoration: none;
    font-size: inherit;
    font-family: inherit;
    font-weight: inherit;
    line-height: inherit;
  }
}
"""

@tags head body tbody thead h1 td th tr span p a br img strong
@tags_noescape style

function make_head(title)
    head(
        m("meta", name = "viewport", content = "width=device-width, initial-scale=1.0"),
        m("meta", httpEquiv = "Content-Type", content = "text/html; charset=UTF-8"),
        m("title", title),
        style(media = "all", type = "text/css", CSS)
    )
end

function make_title(title)
    [
        h1(
            style = "font-family: Roboto, sans-serif; font-size: 42px; font-weight: 700; color: #000000; line-height: 1.18; margin: 0px;",
            title
        ),
        m(
            "div",
            style = "height: 4px; width: 80px; background-color: rgb(0, 150, 130); margin: 6px 0px 24px 0px; padding: 0;"
        )
    ]
end

function make_paragraph(text)
    p(
        style = "font-family: Roboto, sans-serif; text-align: left; font-size: 18px; font-weight: 300; line-height: 1.4;",
        text
    )
end

function make_body(contents)
    body(
        style = "font-family: Roboto, sans-serif; margin: 0; padding: 0; width: 100%; background-color: rgb(239, 239, 239); -webkit-font-smoothing: antialiased; -ms-text-size-adjust: 100%; -webkit-text-size-adjust: 100%;",
        m("table", width = "100%", border = "0", cellspacing = "0",
            cellpadding = "0", style = "width: 100%;",
            tr(
                td(align = "center",
                m("table",
                    class = "content",
                    width = "680",
                    border = "0",
                    cellspacing = "0",
                    cellpadding = "0",
                    style = "border-collapse: collapse; min-height: 100vh; background-color: #ffffff;",
                    [
                        tr(
                            td(class = "main", style = "padding: 80px;",
                            m("table", width = "100%", border = "0",
                                cellspacing = "0", cellpadding = "0",
                                [
                                    tr(
                                    td(content)
                                )
                                ] for content in contents
                            )
                        )
                        ),
                        make_footer()
                    ]
                )
            )
            )
        )
    )
end

function make_footer()
    tr(
        td(
        class = "footer", style = "background-color: rgb(64, 64, 64); padding: 20px 80px;",
        p(
            style = "font-family: Roboto, sans-serif; text-align: left; font-size: 13px; font-weight: 300; color: #ffffff; line-height: 1.1; margin: 0px;",
            [
                "This email was automatically generated, please do not reply to it.",
                br(),
                br(),
                br(),
                "KIT – The Research University in the Helmholtz Association"
            ]
        )
    )
    )
end

function make_html(title, content)
    "<!DOCTYPE html>\n" *
    string(
        Pretty(
        m("html", lang = "en",
        [
            make_head(title),
            make_body(content)
        ]
    )
    )
    )
end

function make_error_html(message, filename)
    make_html(
        "Error Message",
        [
            make_title("Error Message"),
            make_paragraph("An error has occured in DAWN."),
            make_paragraph(message),
            make_paragraph("The log file can be found under: $filename")
        ]
    )
end

function make_signals_html(signals)
    make_html(
        "Signals",
        [
            make_title("Signals"),
            [make_paragraph(signal) for signal in signals]...
        ]
    )
end

function send_email(credentials, receivers, subject, html)
    py"send_email"(credentials.server, credentials.login, credentials.password,
        credentials.sender, receivers, subject, html)
end

function send_error_email(credentials, receivers, message, filename)
    html = make_error_html(message, filename)

    send_email(credentials, receivers, "DAWN Error Message", html)

    @info "Sent error email."
end

function send_signals_email(credentials, receivers, signals)
    html = make_signals_html(signals)

    send_email(credentials, receivers, "DAWN Signals", html)

    @info "Sent signals email."
end