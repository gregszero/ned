# frozen_string_literal: true

require_relative '../test_helper'

class ScrapeWebsiteToolTest < Fang::ToolTestCase
  def setup
    super
    @tool = Fang::Tools::ScrapeWebsiteTool.new
    @calls = []
  end

  def test_basic_scrape_with_defaults
    scraped = { 'title' => 'Hello World', 'body_text' => 'Some content' }

    stub_python_runner(
      run_code: [
        { success: true, result: 'ok' },           # import check
        { success: true, result: JSON.generate(scraped) } # actual scrape
      ]
    ) do
      result = @tool.call(url: 'https://example.com')

      assert result[:success]
      assert_equal 'https://example.com', result[:url]
      assert_equal 'basic', result[:fetcher]
      assert_equal 'Hello World', result[:data]['title']
      assert_equal 'Some content', result[:data]['body_text']
    end
  end

  def test_scrape_with_custom_selectors
    scraped = { 'heading' => 'My Title', 'links' => ['a', 'b'] }
    selectors = [
      { name: 'heading', selector: 'h1', type: 'css', extract: 'text', multiple: false },
      { name: 'links', selector: 'a.nav', type: 'css', extract: 'href', multiple: true }
    ]

    stub_python_runner(
      run_code: [
        { success: true, result: 'ok' },
        { success: true, result: JSON.generate(scraped) }
      ]
    ) do |calls|
      result = @tool.call(url: 'https://example.com', selectors: selectors)

      assert result[:success]
      assert_equal 'My Title', result[:data]['heading']
      assert_equal ['a', 'b'], result[:data]['links']

      # Verify custom selectors appear in the generated Python code
      python_code = calls[:run_code].last.first
      assert_includes python_code, 'heading'
      assert_includes python_code, 'a.nav'
    end
  end

  def test_invalid_fetcher_type
    result = @tool.call(url: 'https://example.com', fetcher_type: 'invalid')

    refute result[:success]
    assert_includes result[:error], "Invalid fetcher_type 'invalid'"
  end

  def test_auto_installs_scrapling
    scraped = { 'title' => 'Test' }

    stub_python_runner(
      run_code: [
        { success: false, error: 'ModuleNotFoundError' }, # import check fails
        { success: true, result: JSON.generate(scraped) } # scrape after install
      ],
      pip_install: [{ success: true, result: 'installed' }]
    ) do |calls|
      result = @tool.call(url: 'https://example.com')

      assert result[:success]
      assert_equal 1, calls[:pip_install].size
      assert_equal 'scrapling', calls[:pip_install].first.first
    end
  end

  def test_python_execution_failure
    stub_python_runner(
      run_code: [
        { success: true, result: 'ok' },
        { success: false, error: 'SyntaxError: unexpected EOF' }
      ]
    ) do
      result = @tool.call(url: 'https://example.com')

      refute result[:success]
      assert_equal 'SyntaxError: unexpected EOF', result[:error]
    end
  end

  def test_tool_group_is_web
    assert_equal :web, Fang::Tools::ScrapeWebsiteTool.tool_group
  end

  def test_playwright_fetcher_with_wait_for
    scraped = { 'title' => 'Dynamic Page' }

    stub_python_runner(
      run_code: [
        { success: true, result: 'ok' },
        { success: true, result: JSON.generate(scraped) }
      ]
    ) do |calls|
      result = @tool.call(url: 'https://example.com', fetcher_type: 'playwright', wait_for: '#content')

      assert result[:success]

      python_code = calls[:run_code].last.first
      assert_includes python_code, 'PlayWrightFetcher'
      assert_includes python_code, 'wait_selector='
      assert_includes python_code, '#content'
    end
  end

  private

  def stub_python_runner(run_code: [], pip_install: [])
    calls = { run_code: [], pip_install: [] }
    run_code_queue = run_code.dup
    pip_install_queue = pip_install.dup

    original_run = Fang::PythonRunner.method(:run_code)
    original_pip = Fang::PythonRunner.method(:pip_install)

    Fang::PythonRunner.define_singleton_method(:run_code) do |*args|
      calls[:run_code] << args
      run_code_queue.shift || { success: false, error: 'unexpected call' }
    end

    Fang::PythonRunner.define_singleton_method(:pip_install) do |*args|
      calls[:pip_install] << args
      pip_install_queue.shift || { success: false, error: 'unexpected call' }
    end

    yield calls
  ensure
    Fang::PythonRunner.define_singleton_method(:run_code, original_run)
    Fang::PythonRunner.define_singleton_method(:pip_install, original_pip)
  end
end
