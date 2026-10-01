require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # All fixture users share the same password (test/fixtures/users.yml).
  # Turbo intercepts the sign-in form submission, so the redirect to the
  # authenticated layout isn't necessarily done by the time click_button
  # returns - waiting for the header (only rendered when Current.user is
  # set) avoids a flaky race against whatever the caller does next.
  def sign_in_as(user)
    visit new_session_path
    fill_in "email", with: user.email
    fill_in "password", with: "password"
    click_button I18n.t("sessions.new.submit")
    assert_selector "header", wait: 20
  end

  # Selenium's native send_keys(:arrow_down/:arrow_up) doesn't reliably
  # raise a JS-visible KeyboardEvent against headless Chrome for every key -
  # dispatching it directly is what the autocomplete controllers actually
  # listen for, and matches real keyboard behavior exactly (same event type,
  # same key value).
  def press_key(element, key)
    page.execute_script(<<~JS, element.native)
      arguments[0].dispatchEvent(new KeyboardEvent("keydown", { key: #{key.to_s.inspect}, bubbles: true, cancelable: true }))
    JS
  end

  # Selenium's coordinate-based native click intermittently never reaches
  # the browser in this sandbox's headless Chrome (no console error, no
  # network request - just silently inert), while a real DOM .click() call
  # always works. Affects buttons/links, same root cause as press_key above.
  def js_click(locator)
    element = locator.respond_to?(:native) ? locator : find_button(locator)
    page.execute_script("arguments[0].click()", element.native)
  rescue Capybara::ElementNotFound
    element = find_link(locator)
    page.execute_script("arguments[0].click()", element.native)
  end

  # Same unreliability as js_click/press_key above, for plain text/number
  # fields: setting .value directly and dispatching "input" is what the
  # page's own JS (recompute, autocomplete) listens for, and is what a real
  # keystroke does too - just without Selenium's flaky native typing path.
  def js_fill_in(locator, with:)
    element = locator.respond_to?(:native) ? locator : find_field(locator)
    page.execute_script(<<~JS, element.native, with.to_s)
      arguments[0].value = arguments[1];
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }));
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end
end
