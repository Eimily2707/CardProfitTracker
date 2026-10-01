require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    patch locale_url(locale: "fr")
    assert_redirected_to new_session_url
  end

  test "updates the signed-in user's locale" do
    sign_in_as(users(:elena))

    patch locale_url(locale: "fr")

    assert_equal "fr", users(:elena).reload.locale
    assert_redirected_to root_url
  end

  test "ignores an unsupported locale" do
    sign_in_as(users(:elena))

    patch locale_url(locale: "xx")

    assert_equal "it", users(:elena).reload.locale
  end

  test "redirects back to the referring page" do
    sign_in_as(users(:elena))

    patch locale_url(locale: "en"), headers: { "HTTP_REFERER" => tasks_url }

    assert_redirected_to tasks_url
  end
end
