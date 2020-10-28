# frozen_string_literal: true

# code by MSP-Greg
# argv[0] 'info json' file

require_relative 'json_pr_issue_base'

module JsonPrIssueUpdate
  class << self
    include JsonPrIssueBase

    def run
      @added, @updated = 0, 0

      fn_json = File.join __dir__, "data_#{REPO}.json"
      @data = JSON.parse File.read(fn_json, mode: 'rb:UTF-8')

      base = "first: #{ROWS}, orderBy: {field: UPDATED_AT, direction: DESC}"

      # 2 queries, 1st is the most recent, 2nd is most recent closed
      ["#{base}, states:OPEN", "#{base}, states:CLOSED"].each do |filter|
        update_data :issue, filter
      end

      # 2 queries, 1st is the most recent, 2nd is most recent closed or merged
      ["#{base}, states:OPEN", "#{base}, states:[CLOSED,MERGED]"].each do |filter|
        update_data :pr, filter
      end

      # sort and write data
      @data = @data.to_a.sort_by { |a| -a[0].to_i }.to_h
      str = JSON.pretty_generate @data
      File.write fn_json, str, mode: 'wb:UTF-8'

      # output info about updates and data stats
      puts (@added + @updated == 0 ? "\nNo items added or updated" :
        "\nAdded #{@added} items, updated #{@updated} items")

      issue_open   = @data.count { |k,d| d['type'] == 'issue' && d['closed'].nil? }
      issue_closed = @data.count { |k,d| d['type'] == 'issue' && !d['closed'].nil? }
      pr_open      = @data.count { |k,d| d['type'] == 'pr'    && d['closed'].nil? }
      pr_closed    = @data.count { |k,d| d['type'] == 'pr'    && !d['closed'].nil? }

      open = [issue_open.to_s.length  , pr_open.to_s.length].max
      clsd = [issue_closed.to_s.length, pr_closed.to_s.length].max

      puts '',
        format("Issues - %#{open}d open, %#{clsd}d closed", issue_open, issue_closed),
        format("PRs    - %#{open}d open, %#{clsd}d closed", pr_open   , pr_closed)

      min, max = 1_000_000, 0
      keys = @data.keys
      keys_i = []
      keys.each do |num|
        num_i = num.to_i
        keys_i << num_i
        min = [min, num_i].min
        max = [max, num_i].max
      end
      missing = (min..max).to_a - keys_i
      if missing.empty?
        puts "\nData has no missing PR/issue numbers", ''
      else
        puts "\nData is missing PR/issues #{missing.join ', '}", ''
      end

      # update the history md file links
      update_history
    end

    # queries GitHub, adds or updates data
    def update_data(type1, filter)
      type2 = type1 == :pr ? :pullRequests : :issues
      query = gql_query_str type2, filter
      body = gql_request query
      ary = body.dig :data, :repository, type2, :edges
      print_error(body, query) unless ary

      ary.each do |h|
        item = h[:node]
        key = item[:number].to_s
        if @data.key? key
          unless item[:closedAt].nil? || @data[key]['closed'] == item[:closedAt]
            @updated += 1
            puts format "#{type1} %5s updated in data", key
            @data[key] = create_obj item, type1
          end
        else
          @added += 1
          puts format "#{type1} %5s added in data", key
          @data[key] = create_obj item, type1
        end
      end
    end

    def update_history
      history = File.read HISTORY, mode: 'rb:UTF-8'

      @links_ary = []

      # replace all links with md link if they exist in PR/issue data
      history.gsub!(/([^\[])#(\d{1,5})([^\]])?/) do |m|
        start = $1
        num   = $2
        end_c = $3

        if @data.key? num
          @links_ary << num
          "#{start}[##{num}]#{end_c}"
        else
          puts "History text/number '##{num}' is not found in PR/Issue data?"
          m
        end
      end

      @links_ary.clear
      history.scan(/[ (]\[\#(\d{1,5})\]/) { |num| @links_ary << num.first }

      links = create_links_str

      history.sub!(/^\[\#\d{1,5}\]:http.+/m, links)
      File.write HISTORY, history, mode: 'wb:UTF-8'
    end

    def create_links_str
      str = ''.dup
      @links_ary.uniq.each do |num|
        t = @data[num]
        next unless t

        str << "[##{num}]:https://github.com/#{OWNER}/#{REPO}/"
        type = t['type']
        len = num.length
        uri_end = (type == 'pr' ? "pull/#{num}" : "issues/#{num}").ljust(18 - len)
        str << uri_end
        str << (type == 'pr' ? '"PR' : '"Issue')
        str <<  " by #{t['user_name']},"
        str << case t['state']
        when 'MERGED' then " merged #{t['closed'][0,10]}\"\n"
        when 'CLOSED' then " closed #{t['closed'][0,10]}\"\n"
        else               " opened #{t['opened'][0,10]}\"\n"
        end
      end
      str
    end
  end
end

JsonPrIssueUpdate.run
