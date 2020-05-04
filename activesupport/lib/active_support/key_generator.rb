# frozen_string_literal: true

require "concurrent/map"
require "openssl"

module ActiveSupport
  # KeyGenerator is a simple wrapper around OpenSSL's implementation of PBKDF2.
  # It can be used to derive a number of keys for various purposes from a given secret.
  # This lets Rails applications have a single secure secret, but avoid reusing that
  # key in multiple incompatible contexts.
  class KeyGenerator
    def initialize(secret, options = {})
      @secret = secret
      # The default iterations are higher than required for our key derivation uses
      # on the off chance someone uses this for password storage
      @iterations = options[:iterations] || 2**16
    end

    # Returns a derived key suitable for use.  The default key_size is chosen
    # to be compatible with the default settings of ActiveSupport::MessageVerifier.
    # i.e. OpenSSL::Digest::SHA1#block_length
    def generate_key(salt, key_size = 64)
      OpenSSL::PKCS5.pbkdf2_hmac_sha1(@secret, salt, @iterations, key_size)
    end
  end

  # CachingKeyGenerator is a wrapper around KeyGenerator which allows users to avoid
  # re-executing the key generation process when it's called using the same salt and
  # key_size.
  class CachingKeyGenerator
    def initialize(key_generator)
      @key_generator = key_generator
      @cache_keys = Concurrent::Map.new
    end

    # Returns a derived key suitable for use.
    def generate_key(*args)
      @cache_keys[args.join('|')] ||= @key_generator.generate_key(*args)
    end
  end
end
