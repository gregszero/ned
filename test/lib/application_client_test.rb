# frozen_string_literal: true

require_relative '../test_helper'

class TestClient < Fang::ApplicationClient
  BASE_URI = "https://api.example.com/v1"
end

class ApplicationClientTest < Fang::TestCase
  def setup
    super
    @client = TestClient.new(token: 'test-token')
  end

  def test_get_request
    stub_request(:get, "https://api.example.com/v1/widgets")
      .to_return(
        status: 200,
        body: '{"name": "Widget A"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @client.get('/widgets')
    assert_equal '200', response.code
    assert_equal 'Widget A', response.name
  end

  def test_post_request
    stub_request(:post, "https://api.example.com/v1/widgets")
      .with(body: '{"name":"New Widget"}')
      .to_return(
        status: 201,
        body: '{"id": 1, "name": "New Widget"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @client.post('/widgets', body: { name: 'New Widget' })
    assert_equal '201', response.code
    assert_equal 1, response.id
  end

  def test_authorization_header
    stub_request(:get, "https://api.example.com/v1/me")
      .with(headers: { 'Authorization' => 'Bearer test-token' })
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

    @client.get('/me')
    assert_requested(:get, "https://api.example.com/v1/me",
      headers: { 'Authorization' => 'Bearer test-token' })
  end

  def test_no_auth_without_token
    client = TestClient.new
    stub_request(:get, "https://api.example.com/v1/public")
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

    client.get('/public')
    # Should not include Authorization header
    assert_requested(:get, "https://api.example.com/v1/public") do |req|
      !req.headers.key?('Authorization')
    end
  end

  def test_404_raises_not_found
    stub_request(:get, "https://api.example.com/v1/missing")
      .to_return(status: 404, body: 'Not found')

    assert_raises(TestClient::NotFound) { @client.get('/missing') }
  end

  def test_401_raises_unauthorized
    stub_request(:get, "https://api.example.com/v1/secret")
      .to_return(status: 401, body: 'Unauthorized')

    assert_raises(TestClient::Unauthorized) { @client.get('/secret') }
  end

  def test_403_raises_forbidden
    stub_request(:get, "https://api.example.com/v1/admin")
      .to_return(status: 403, body: 'Forbidden')

    assert_raises(TestClient::Forbidden) { @client.get('/admin') }
  end

  def test_429_raises_rate_limit
    stub_request(:get, "https://api.example.com/v1/busy")
      .to_return(status: 429, body: 'Too Many Requests')

    assert_raises(TestClient::RateLimit) { @client.get('/busy') }
  end

  def test_500_raises_internal_error
    stub_request(:get, "https://api.example.com/v1/broken")
      .to_return(status: 500, body: 'Internal Server Error')

    assert_raises(TestClient::InternalError) { @client.get('/broken') }
  end

  def test_query_params
    stub_request(:get, "https://api.example.com/v1/search?q=test&page=1")
      .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

    @client.get('/search', query: { q: 'test', page: 1 })
    assert_requested(:get, "https://api.example.com/v1/search?q=test&page=1")
  end

  def test_inherited_error_classes
    assert TestClient::Error < Fang::ApplicationClient::Error
    assert TestClient::NotFound < Fang::ApplicationClient::NotFound
  end

  def test_json_parsed_to_openstruct
    stub_request(:get, "https://api.example.com/v1/item")
      .to_return(
        status: 200,
        body: '{"id": 42, "nested": {"key": "val"}}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @client.get('/item')
    assert_equal 42, response.id
    assert_equal 'val', response.nested.key
  end
end
