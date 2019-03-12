ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "history.txt")
    assert_includes(last_response.body, "changes.txt")
    assert_includes(last_response.body, "about.txt")
  end

  def test_history_file
    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "This is a history of the project.")
  end

  def test_invalid_file_request
    get "/notafile.ext"
    assert_equal(302, last_response.status)
    # assert_equal("http://localhost:4567/", last_response["Location"]) Why doesn't this work?
    get last_response["Location"]
    assert_includes last_response.body "notafile.ext does not exist"
    get "/"
    refute_includes "notafile.ext does not exist"
  end


end
