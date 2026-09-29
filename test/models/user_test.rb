require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email" do
    user = User.new(email: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email)
  end

  test "requires an email" do
    user = User.new(email: "", password: "password", time_zone: "UTC")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires a unique email, case-insensitively (citext)" do
    duplicate = User.new(email: users(:elena).email.upcase, password: "password", time_zone: "UTC")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "valid with the required attributes" do
    user = User.new(email: "new@example.com", password: "password", time_zone: "UTC")
    assert user.valid?
  end

  test "accepts any of the 5 supported locales, or none" do
    User::SUPPORTED_LOCALES.each do |locale|
      user = User.new(email: "new@example.com", password: "password", time_zone: "UTC", locale: locale)
      assert user.valid?, "expected locale #{locale.inspect} to be valid"
    end

    assert User.new(email: "new@example.com", password: "password", time_zone: "UTC", locale: nil).valid?
  end

  test "rejects a locale outside the 5 supported ones" do
    user = User.new(email: "new@example.com", password: "password", time_zone: "UTC", locale: "pt")
    assert_not user.valid?
    assert_includes user.errors[:locale], "is not included in the list"
  end

  test "requires a time_zone" do
    user = User.new(email: "new@example.com", password: "password", time_zone: nil)
    assert_not user.valid?
    assert_includes user.errors[:time_zone], "can't be blank"
  end

  test "rejects a time_zone that ActiveSupport::TimeZone does not recognize" do
    user = User.new(email: "new@example.com", password: "password", time_zone: "Not/AZone")
    assert_not user.valid?
    assert_includes user.errors[:time_zone], "is not a valid time zone"
  end

  test "confirmed? reflects confirmed_at" do
    assert users(:elena).confirmed?
    assert_not User.new.confirmed?
  end

  test "otp_secret is stored encrypted at rest" do
    user = users(:elena)
    user.update!(otp_secret: "topsecret")

    ciphertext = ActiveRecord::Base.connection.select_value(
      "SELECT otp_secret FROM users WHERE id = #{user.id}"
    )

    assert_not_nil ciphertext
    assert_not_equal "topsecret", ciphertext
    assert_equal "topsecret", user.reload.otp_secret
  end

  test "has_many memberships and accounts through them" do
    assert_includes users(:elena).accounts, accounts(:acme)
    assert_not_includes users(:elena).accounts, accounts(:globex)
  end
end
