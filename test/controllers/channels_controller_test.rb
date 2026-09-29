require "test_helper"

class ChannelsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get channels_url
    assert_redirected_to new_session_url
  end

  test "lists the account's channels" do
    sign_in_as(users(:elena))

    get channels_url

    assert_response :success
    assert_select "td", text: /Fiera/
  end

  test "a viewer cannot create a channel" do
    sign_in_as(users(:viewer_user))

    assert_no_difference -> { Channel.count } do
      post channels_url, params: { channel: { name: "eBay Italia", kind: "marketplace", usage: "both" } }
    end

    assert_response :redirect
  end

  test "an operator can create a custom channel" do
    sign_in_as(users(:operator_user))

    assert_difference -> { Channel.count }, 1 do
      post channels_url, params: { channel: { name: "eBay Italia", kind: "marketplace", usage: "both", credit_timing: "manual" } }
    end

    assert_redirected_to channels_url
  end

  test "cannot destroy a system channel" do
    sign_in_as(users(:elena))

    assert_no_difference -> { Channel.count } do
      delete channel_url(channels(:acme_fair))
    end

    assert_redirected_to channels_url
  end

  test "can destroy a custom channel with no purchases" do
    sign_in_as(users(:elena))

    assert_difference -> { Channel.count }, -1 do
      delete channel_url(channels(:acme_private))
    end
  end
end
