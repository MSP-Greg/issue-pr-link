# frozen_string_literal: true

# code by MSP-Greg
# argv[0] 'info json' file

require_relative 'json_pr_issue_base'

module JsonPrIssueAll
  class << self
    include JsonPrIssueBase

    def run
      t_st = Time.now.to_f
      fn_json = File.join __dir__, "data_#{REPO}.json"
      @data = {}

      do_data :issue
      do_data :pr

      # sort and write data
      @data = @data.to_a.sort_by { |a| -a[0].to_i }.to_h
      str = JSON.pretty_generate @data
      File.write fn_json, str, mode: 'wb:UTF-8'

      # below is just a check
      str = File.read fn_json, mode: 'rb:UTF-8'
      keys_ary = JSON.parse(str).keys.map(&:to_i)
      puts ''
      puts format "first %5d", keys_ary.min
      puts format "last  %5d", keys_ary.max
      puts format "count %5d   max-min+1 = %d", keys_ary.length,
        keys_ary.max - keys_ary.min + 1

      puts '', '%5.2f seconds' % (Time.now.to_f - t_st)

    end

    def do_data(type1)
      offset_str = ''
      continue = true
      type2 = type1 == :pr ? :pullRequests : :issues
      while continue
        filter = "first: #{ROWS}#{offset_str}"
        query = gql_query_str type2, filter
        body = gql_request query

        # get info on next endCursor
        cursor = body.dig :data, :repository, type2, :pageInfo
        print_error(body, query) unless cursor
        if cursor[:hasNextPage]
          offset_str = ", after: \"#{cursor[:endCursor]}\""
        else
          continue = false
        end

        # process data
        ary = body.dig :data, :repository, type2, :edges
        print_error(body, query) unless ary
        puts "#{type1} loop"
        ary.each do |h|
          item = h[:node]
          key = item[:number].to_s
          @data[key] = create_obj(item, type1) unless @data.key? key
        end
      end
    end
  end
end

JsonPrIssueAll.run
