# Ridify in the browser

This web target compiles **the same `frontend/lib` screens, services, navigation,
providers, and assets as the mobile app**. It does not edit any existing app or
backend file. The phone layout fills narrow browsers and stays centered at a
maximum width of 480px on desktop. Every build takes a fresh copy of the mobile
source, so future app changes are automatically included.

## Publish on Render

1. Push this repository to GitHub, then in Render select **New → Blueprint**
   and connect the repository. The root `render.yaml` creates `ridify` as a
   **Static Site**; it does not recreate your API or database.
2. The Blueprint sets `BACKEND_URL` to the `ridify-backend` service at
   `https://ridify-backend.onrender.com`.
3. On the existing backend service, set **`ALLOWED_ORIGIN`** (singular) to the
   exact website origin Render assigns, `https://ridify.onrender.com`.
   Redeploy the backend after the environment change. Use the actual assigned
   hostname, which may include a suffix.
4. Open the website. Existing accounts and rides use the same backend/database.
   Allow browser location access for pickup autofill and live GPS.

For manual setup choose **Static Site**, leave Root Directory empty, set Build
Command to `bash web-app/build.sh`, Publish Directory to `web-app/dist`, and
add the environment variable, headers and rewrite from `render.yaml`.

**Existing backend limitation:** HTTP CORS accepts a comma-separated list, but
Socket.IO currently treats `ALLOWED_ORIGIN` as one string. Use a single canonical
web origin for both HTTP and realtime connections. If you already have another
web origin configured, multi-origin support needs a separate backend change;
do not simply append a second origin and expect chat/tracking to work. Native
mobile code is unchanged by this web target.

## Local build

Requires Node.js and Git. If Flutter is absent, the build installs Flutter 3.44.3
inside the ignored `web-app/.flutter-sdk` directory. An installed Flutter is used
as-is; 3.44.3 is the tested version. Locked Dart dependencies are enforced.

```sh
BACKEND_URL=https://your-api.onrender.com bash web-app/build.sh
python3 -m http.server 8080 --directory web-app/dist
```

Open `http://localhost:8080`. Your backend must allow that origin for browser
requests. For a local HTTP API only:

```sh
ALLOW_HTTP_LOCALHOST=1 BACKEND_URL=http://localhost:5001 bash web-app/build.sh
```

The build runs dedicated screen tests before compiling. Output is ignored by
Git. It stages only Dart source, assets and dependency manifests in a temporary
directory, generates an environment asset containing **only the public backend
URL**, and deletes staging on exit. The existing `frontend/.env`, mobile native
projects, dependency lockfile, and original web scaffold are never modified.
Changing `BACKEND_URL` requires rebuilding the static site.

## Screen coverage and browser behavior

| Flow | Shared implementation |
| --- | --- |
| Startup and session restoration | Splash animation, secure token storage, config fetch |
| Login / signup | Password or email OTP, signup validation |
| Home | Offer/find actions, earnings/spending, bottom navigation |
| Offer | Addresses, map selection, route, vehicle, seats, fare, departure |
| Find / results | Pickup, destination, radius, date/time, filters, sorting, requests |
| Active rides | Driver acceptance/decline, passenger requests, cancellation |
| Live ride | Map, GPS stream, arrival, boarding, drop-off, completion |
| Chat | Ride messages, replies, shared locations, reconnect/polling |
| Completion / history | Driver summary, passenger payment acknowledgement, past rides |
| Account | Profile, password, ID upload, verification, theme, logout |
| Admin | Dashboard, users, rides, verification with existing authorization |

Browser differences: HTTPS is required for deployed geolocation and secure
storage; localhost is allowed for development. GPS can stop when the browser is
backgrounded or the phone locks, so keep the ride tab open for live tracking.
Camera capture depends on the browser; file selection remains available. Maps,
address lookup and routing still use the app's existing external services and
need internet access. Browser storage is separate from the installed app's
storage. This is an online app, not an offline ride client.

## Verification before public use

Automated checks cover login/signup layouts at phone and desktop-shell widths,
light/dark themes, required-email validation, offer form, and empty history.
Use two real test accounts after configuring Render to verify password/OTP
login, ID upload, offer → search → request → accept → live tracking → chat →
completion/payment, reload/session restoration, and logout. Real OTP delivery,
GPS movement, and production Socket.IO require the deployed backend and are
not proven by a successful static build.

References: [Flutter web initialization](https://docs.flutter.dev/platform-integration/web/initialization),
[Render static sites](https://render.com/docs/static-sites),
[Render Blueprint configuration](https://render.com/docs/blueprint-spec).
