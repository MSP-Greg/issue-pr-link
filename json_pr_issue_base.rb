# frozen_string_literal: true

# code by MSP-Greg
# file is included in json_pr_issue_all.rb and json_history_update.rb

require 'json'
require 'net/http'

module JsonPrIssueBase

  fn_cred = ARGV[0]

  if File.exist? fn_cred
    cred = JSON.parse(File.read fn_cred, mode: 'rb:UTF-8')
  else
    puts "Filename passed as ARGV doesn't exist!"
    exit
  end

  OWNER   = cred['owner']
  REPO    = cred['repo']
  HISTORY = cred['history']
  TKN     = cred['token']
  ROWS    = 100               # gql_request query, limit of 100

  if !File.exist? HISTORY
    puts 'History filename in json file doesn\'t exist!'
    exit
  elsif TKN.length != 40
    puts 'token must be 40 characters!'
    exit
  elsif !(OWNER.is_a?(::String) && REPO.is_a?(::String) && !OWNER.empty? && !REPO.empty?)
    puts 'owner and repo must be non-empty strings!'
    exit
  end

  # creates a hash of the issue or pr data
  def create_obj(item, type)
    {
      'opened' => item[:createdAt],
      'closed' => item[:closedAt],
      'state'  => item[:state],
      'type'   => type,
      # remove [ci skip] type strings
      'title'  => item[:title].gsub(/\s*\[[a-z ]+\]\s*/, ''),
      'author' => item.dig(:author, :name),
      'user_name' => "@#{item.dig :author, :login}"
    }
  end

  # get the GraphQL data from GitHub given the query
  def gql_request(query, filename: nil)
    body = {}
    body['query'] = query
    data = nil
    Net::HTTP.start('api.github.com', 443, use_ssl: true) do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER 
      req = Net::HTTP::Post.new '/graphql'
      req['Authorization'] = "Bearer #{TKN}"
      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req.body = JSON.generate body
      resp = http.request req
      if Net::HTTPSuccess === resp
        data = JSON.parse resp.body, symbolize_names: true
        if filename
          File.write "#{__dir__}/#{filename}", resp.body, mode: 'wb:UTF-8'
        end
      else
        return nil
      end
    end
    data
  end

  # prints debug info if the GitHub API finds and error
  def print_error(data, gql)
    puts 'Error retrieving GraphQL data'
    puts gql
    pp data
    exit
  end

  # returns the gql_request query string
  def gql_query_str(obj, filter)
    <<~GRAPHQL
      query {
        repository(owner: "#{OWNER}", name: "#{REPO}") {
          #{obj}(#{filter}) {
            edges {
              node {
                number
                createdAt
                closedAt
                state
                title
                author {
                  ... on User {
                    login
                    name
                  }
                }
              }
            }
            pageInfo {
              endCursor
              hasNextPage
            }
          }
        }
      }
    GRAPHQL
  end
end
