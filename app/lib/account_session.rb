# frozen_string_literal: true

class AccountSession
  class Frozen < StandardError; end

  class ReauthenticateUserError < StandardError; end

  class SessionTooOld < ReauthenticateUserError; end

  class SessionVersionInvalid < ReauthenticateUserError; end

  class MissingCachedAttribute < ReauthenticateUserError; end

  CURRENT_VERSION = 1

  attr_reader :id_token, :user_id

  def initialize(session_secret:, **options)
    raise SessionTooOld unless options[:digital_identity_session]

    @access_token = options.fetch(:access_token)
    @id_token = options[:id_token]
    @refresh_token = options[:refresh_token]
    @session_secret = session_secret
    @frozen = false

    if options[:version].nil?
      options.merge!(mfa: options[:level_of_authentication] == "level1") unless options.key?(:mfa)
      options.merge!(user_id: userinfo["sub"]) unless options.key?(:user_id)
    elsif options[:version] != CURRENT_VERSION
      raise SessionVersionInvalid
    end

    @mfa = options.fetch(:mfa, false)
    @user_id = options.fetch(:user_id)
  end

  def self.deserialise(encoded_session:, session_secret:)
    encoded_session_without_flash = encoded_session&.split("$$")&.first
    return if encoded_session_without_flash.blank?

    serialised_session = StringEncryptor.new(secret: session_secret).decrypt_string(encoded_session_without_flash)
    return unless serialised_session

    deserialised_options = JSON.parse(serialised_session).symbolize_keys
    return if deserialised_options.blank?

    new(session_secret: session_secret, **deserialised_options)
  rescue OidcClient::OAuthFailure, ReauthenticateUserError
    nil
  end

  def user
    @user ||= OidcUser.find_or_create_by_sub!(user_id)
  end

  def mfa?
    @mfa
  end

  def serialise
    @frozen = true
    StringEncryptor.new(secret: session_secret).encrypt_string(to_hash.to_json)
  end

  def to_hash
    {
      id_token: id_token,
      user_id: user_id,
      digital_identity_session: true,
      mfa: @mfa,
      access_token: @access_token,
      refresh_token: @refresh_token,
      version: CURRENT_VERSION,
    }
  end

  def get_attributes(attribute_names)
    values_to_cache = attribute_names.select { |name| user_attributes.type(name) == "cached" }.select { |name| user[name].nil? }
    raise MissingCachedAttribute unless values_to_cache.empty?

    user.get_attributes_by_name(attribute_names).compact
  end

  def set_attributes(attributes)
    user.update!(attributes)
  end

  def userinfo
    @userinfo ||= begin
      userinfo_hash = oidc_do :userinfo
      # TODO: Remove this special case after removing the use of the
      # has_unconfirmed_email attribute in other apps.
      userinfo_hash.merge("has_unconfirmed_email" => false)
    end
  end

private

  attr_reader :session_secret

  def oidc_do(method, args = {})
    raise Frozen if @frozen

    oauth_response = oidc_client.public_send(
      method,
      **args.merge(access_token: @access_token, refresh_token: @refresh_token),
    )
    @access_token = oauth_response[:access_token]
    @refresh_token = oauth_response[:refresh_token]
    oauth_response[:result]
  end

  def oidc_client
    @oidc_client ||=
      if Rails.env.development?
        OidcClient::Fake.new
      else
        OidcClient.new
      end
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
