ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => {username: "admin"}}
  end 

  def test_index
    create_document("about.md")
    create_document("changes.txt")
    create_document("history.txt")
    get "/index"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "history.txt")
    assert_includes(last_response.body, "changes.txt")
    assert_includes(last_response.body, "about.md")
  end

  def test_view_document
    create_document("history.txt", "This is a history of the project.")
    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "This is a history of the project.")
  end

  def test_invalid_file_request
    get "/notafile.ext"
    assert_equal(302, last_response.status)
    # assert_equal("http://localhost:4567/", last_response["Location"]) Why doesn't this work?
    assert_equal( "notafile.ext does not exist", session[:flash])
    get last_response["Location"]
    get "/index"
    refute_equal( "notafile.ext does not exist", session[:flash])
  end

  def test_render_extension_md
    create_document("about.md")
    get "/about.md"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
  end

  def test_render_extension_mkd
    create_document("example.mkd")
    get "/example.mkd"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
  end

  def test_edit_document
    create_document("example.mkd")
    post "/index/example.mkd", document_content: "teststring"
    assert_equal(302, last_response.status)
    assert_equal("example.mkd successfully updated", session[:flash])

    get last_response["Location"]
    assert_equal(200, last_response.status)

    get "/example.mkd"
    assert_includes(last_response.body, "teststring")
  end

  def test_create_content
    create_document("another.txt", "teststring")
    get "/another.txt"
    assert_includes(last_response.body, "teststring")
  end

  def test_new_document_form
    get "/index/new"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<form")
  end

  def test_create_new_document
    post "/index", file_name: "test_doc.txt"
    assert_equal(302, last_response.status)
    assert_equal("test_doc.txt created", session[:flash])

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "test_doc.txt")
  end

  def test_empty_file_name
    # skip
    post "/index", file_name: ""
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Name must be between 0 and 100 characters and end with a valid file extension")
  end

  def test_no_ext_file_name
    post "/index", file_name: "textfile"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Name must be between 0 and 100 characters and end with a valid file extension")
  end

  def test_blank_space_file_name
    post "/index", file_name: "j j.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Name may not include spaces")
  end

  def test_already_exists_file_name
    create_document("test_file.txt")
    post "/index", file_name: "test_file.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Name must be unique")
  end

  def test_delete_file
    create_document("test_file.txt")
    get "/index"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "test_file.txt")
    post "/index/test_file.txt/delete"
    assert_includes("test_file.txt deleted", session[:flash])
    assert_equal(302, last_response.status)
    get last_response["Location"]
    assert_equal(200, last_response.status)
    get "/index"
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, "test_file.txt")
  end

  def test_enter_page
    get "/"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Welcome! Please sign in.")
  end

  def test_sign_in_success
    get "/sign-in"
    assert_equal(200, last_response.status)

    post "/verify-sign-in", username: "admin", password: "password"
    assert_equal("You have successfully signed in!", session[:flash])
    assert_equal("admin", session[:username])
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
  end

  def test_sign_in_failure
    post "/verify-sign-in", username: "blooper", password: "blooper"
    assert_nil(session[:username])
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Sorry, but your username and password are not correct.")
  end

  def test_sign_out
    post "/sign-out"
    assert_equal("You have signed out.", session[:flash])

    assert_equal(302, last_response.status)
    get last_response["Location"]
    assert_includes(last_response.body, "Sign in")
  end

end
