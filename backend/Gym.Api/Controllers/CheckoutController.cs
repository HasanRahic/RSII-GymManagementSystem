using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("checkout")]
[AllowAnonymous]
[ApiExplorerSettings(IgnoreApi = true)]
public class CheckoutController : ControllerBase
{
    [HttpGet("success")]
    public IActionResult Success([FromQuery(Name = "session_id")] string? sessionId)
    {
        var safeSessionId = string.IsNullOrWhiteSpace(sessionId) ? "N/A" : sessionId;
        const string htmlTemplate = """
<!DOCTYPE html>
<html lang=\"bs\">
<head>
  <meta charset=\"UTF-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
  <title>Uplata uspješna</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f8fafc; margin: 0; }
    .card { max-width: 620px; margin: 48px auto; background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08); }
    h1 { margin-top: 0; color: #0f172a; }
    p { color: #334155; line-height: 1.5; }
    .ok { color: #166534; font-weight: 700; }
    .meta { font-size: 13px; color: #64748b; margin-top: 12px; }
  </style>
</head>
<body>
  <div class=\"card\">
    <h1>Uplata je uspješno pokrenuta</h1>
    <p class=\"ok\">Checkout je završen. Možete se vratiti u aplikaciju.</p>
    <p>Status transakcije će biti automatski potvrđen putem webhook-a.</p>
    <p class=\"meta\">Stripe session: __SESSION_ID__</p>
  </div>
</body>
</html>
""";

        var html = htmlTemplate.Replace("__SESSION_ID__", safeSessionId);

        return Content(html, "text/html");
    }

    [HttpGet("cancel")]
    public IActionResult Cancel()
    {
        const string html = """
<!DOCTYPE html>
<html lang=\"bs\">
<head>
  <meta charset=\"UTF-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
  <title>Uplata otkazana</title>
  <style>
    body { font-family: Arial, sans-serif; background: #fff7ed; margin: 0; }
    .card { max-width: 620px; margin: 48px auto; background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 8px 24px rgba(124, 45, 18, 0.12); }
    h1 { margin-top: 0; color: #7c2d12; }
    p { color: #9a3412; line-height: 1.5; }
  </style>
</head>
<body>
  <div class=\"card\">
    <h1>Uplata je otkazana</h1>
    <p>Narudžba nije naplaćena. Možete pokušati ponovo iz aplikacije.</p>
  </div>
</body>
</html>
""";

        return Content(html, "text/html");
    }
}