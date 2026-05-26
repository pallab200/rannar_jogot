# Privacy Policy Setup Guide

## Overview
Google Play requires a privacy policy for all apps that handle user data. Your Rannar Jogot app collects minimal data (favorites, preferences locally; video/ad data via third parties), so a clear privacy policy is essential for compliance.

## Step 1: Host the Privacy Policy

You have several free options:

### Option A: GitHub Pages (Recommended)
1. Create a `gh-pages` branch in your repo
2. Add `PRIVACY_POLICY.md` to the root
3. Enable GitHub Pages in repo Settings → Pages → Source: `gh-pages` branch
4. URL will be: `https://<your-github-username>.github.io/<repo-name>/PRIVACY_POLICY.md`

**Alternative:** Add to your repo's `docs/` folder and link to the raw file:
- URL: `https://raw.githubusercontent.com/<your-username>/<repo>/main/PRIVACY_POLICY.md`

### Option B: Google Sites (Free, simple)
1. Create a free Google Site: https://sites.google.com
2. Create a new page for the privacy policy
3. Copy the text from `PRIVACY_POLICY.md`
4. Note the published URL

### Option C: Your Own Website
If you have a domain, host the privacy policy there.

## Step 2: Customize the Privacy Policy

Edit `PRIVACY_POLICY.md` and fill in:
- **[Your Contact Email]:** Use a real email (e.g., `support@rannarjogot.app`)
- **[your-repo]:** Your GitHub username/repo (if using GitHub)
- Add any additional data practices specific to your app

## Step 3: Add to Google Play Console

1. Log in to Google Play Console: https://play.google.com/console
2. Select your app (Rannar Jogot)
3. Navigate to **Store listing** → **App content**
4. Scroll to **Privacy Policy** (or **Privacy Policy URL**)
5. Paste the full URL to your hosted privacy policy
6. **Save & Review**

### Example URLs:
- GitHub: `https://github.com/username/rannar_jogot/blob/main/PRIVACY_POLICY.md`
- GitHub Raw: `https://raw.githubusercontent.com/username/rannar_jogot/main/PRIVACY_POLICY.md`
- Google Sites: `https://sites.google.com/view/rannar-jogot-privacy`

## Step 4: Verify Content Requirements

Google Play requires the policy to cover:
- ✅ What data is collected
- ✅ How data is used
- ✅ Third-party sharing (YouTube, Google Ads)
- ✅ User rights (local deletion, ad opt-out)
- ✅ Children's data (if target audience includes <13)
- ✅ Contact information

All covered in the provided `PRIVACY_POLICY.md`.

## Step 5: Test & Submit

1. Verify the URL is publicly accessible
2. Check that the page loads correctly
3. Ensure no 404 errors in Play Console
4. Submit your app for review

## Common Issues

**"Policy is too vague"** → Specify data types (e.g., "video IDs", "ad analytics")
**"Missing third-party links"** → Add Google, YouTube, and other service links
**"No contact info"** → Add your email or support channel
**"Not accessible"** → Verify the URL is publicly available (no login required)

## Next Steps

1. **Update the privacy policy** with your actual contact email
2. **Host it** using one of the methods above
3. **Add the URL** to Google Play Console
4. **Resubmit** your app for review if needed

---

**Note:** Keep this policy updated whenever you add new features or third-party services that collect data.
