const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

const LOGIN_POST_PATHS = [
  /\/login\/?$/i,
  /\/toLogin\/?$/i,
  /\/j_acegi_security_check\/?$/i,
  /\/j_spring_security_check\/?$/i,
  /\/v\d+\/auth\/(?:users\/)?login\/?$/i,
];

const READ_ONLY_POST_PATHS = [
  /\/ajaxBuildQueue\/?$/i,
  /\/ajaxExecutors\/?$/i,
  /\/chartInfo\/?$/i,
  /\/pageList\/?$/i,
  /\/logDetailCat\/?$/i,
  /\/loadById\/?$/i,
  /\/nextTriggerTime\/?$/i,
];

const DANGEROUS_GET_SEGMENTS = new Set([
  "add",
  "build",
  "buildwithparameters",
  "cancelqueue",
  "create",
  "delete",
  "disable",
  "dodelete",
  "enable",
  "execute",
  "exit",
  "publish",
  "remove",
  "restart",
  "run",
  "saferestart",
  "save",
  "shutdown",
  "start",
  "stop",
  "toggleoffline",
  "trigger",
  "update",
]);

function isAllowedPost(pathname) {
  return [...LOGIN_POST_PATHS, ...READ_ONLY_POST_PATHS].some((pattern) =>
    pattern.test(pathname),
  );
}

function isDangerousGet(pathname) {
  return pathname
    .split("/")
    .filter(Boolean)
    .some((segment) => DANGEROUS_GET_SEGMENTS.has(segment.toLowerCase()));
}

module.exports.default = async ({ page }) => {
  await page.route("**/*", async (route) => {
    const request = route.request();
    const method = request.method().toUpperCase();
    const url = new URL(request.url());

    const allowed =
      (SAFE_METHODS.has(method) && !isDangerousGet(url.pathname)) ||
      (method === "POST" && isAllowedPost(url.pathname));

    if (allowed) {
      await route.continue();
      return;
    }

    console.error(
      `[READONLY-GUARD] BLOCKED ${method} ${url.origin}${url.pathname}`,
    );
    await route.abort("blockedbyclient");
  });
};
