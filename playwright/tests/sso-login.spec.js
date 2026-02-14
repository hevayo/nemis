import { test, expect } from "@playwright/test";

const USERNAME = process.env.TEST_USERNAME || "admin";
const PASSWORD = process.env.TEST_PASSWORD || "admin";

/**
 * Perform a full SSO login via the WSO2 Identity Server form.
 * Goes to /login, clicks the Login button, fills the IS form, and waits
 * for the redirect back to /dashboard.
 */
async function performLogin(page) {
  await page.goto("/login");
  await page.waitForLoadState("networkidle");

  // Click the app's Login button (LoginButton.jsx)
  const loginButton = page.getByRole("button", { name: "Login" });
  await expect(loginButton).toBeVisible({ timeout: 15_000 });
  await loginButton.click();

  // Wait for redirect to the Identity Server login page
  await page.waitForURL(
    (url) => url.hostname !== new URL(page.context()._options.baseURL || "").hostname,
    { timeout: 30_000 }
  );

  // Fill the IS login form — selectors use fallback chains for version compat
  const usernameInput = page.locator(
    'input[id="usernameUserInput"], input[name="username"]'
  ).first();
  await expect(usernameInput).toBeVisible({ timeout: 15_000 });
  await usernameInput.fill(USERNAME);

  // Some IS versions have a two-step form (username → Continue → password)
  const continueButton = page.locator(
    'button[type="submit"], button:has-text("Continue"), button:has-text("Sign In")'
  ).first();
  await continueButton.click();

  // Fill password — may appear on the same or a subsequent page
  const passwordInput = page.locator(
    'input[id="password"], input[name="password"]'
  ).first();
  await expect(passwordInput).toBeVisible({ timeout: 15_000 });
  await passwordInput.fill(PASSWORD);

  // Submit the login form
  const submitButton = page.locator(
    'button[type="submit"], button:has-text("Sign In"), button:has-text("Continue")'
  ).first();
  await submitButton.click();

  // Wait for the OIDC callback to process and redirect to /dashboard
  await page.waitForURL("**/dashboard", { timeout: 30_000 });
  await page.waitForLoadState("networkidle");
}

test.describe("SSO Login Flow", () => {
  test("should redirect unauthenticated users to /login", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // The auth guard should redirect to /login
    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 });
  });

  test("should complete full SSO login and reach dashboard", async ({ page }) => {
    await performLogin(page);

    // Verify the dashboard loaded with the welcome banner (Dashboard.jsx)
    await expect(page.getByText("Welcome Back,")).toBeVisible({ timeout: 15_000 });
  });

  test("should logout and return to login page", async ({ page }) => {
    await performLogin(page);

    // Click the LOGOUT button (LogoutButton.jsx — text is uppercased via CSS)
    // There are two logout buttons (sidebar + main); target the one in <main>
    const logoutButton = page.getByRole("main").getByRole("button", { name: /logout/i });
    await expect(logoutButton).toBeVisible({ timeout: 10_000 });
    await logoutButton.click();

    // Confirm in the modal (LogoutButton.jsx)
    const confirmButton = page.getByRole("button", { name: "Yes, I'm sure" });
    await expect(confirmButton).toBeVisible({ timeout: 5_000 });
    await confirmButton.click();

    // Should redirect back to /login after sign-out
    await expect(page).toHaveURL(/\/login/, { timeout: 30_000 });
  });

  test("should block unauthenticated access to /dashboard", async ({ page }) => {
    await page.goto("/dashboard");
    await page.waitForLoadState("networkidle");

    // ProtectedRoute should redirect to /login
    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 });

    // Dashboard content should not be visible
    await expect(page.getByText("Welcome Back,")).not.toBeVisible();
  });
});
