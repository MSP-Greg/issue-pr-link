#!/usr/bin/env ruby
# frozen_string_literal: true

# code by MSP-Greg
# argv[0] 'info json' file, argv[1] version/tag string
# run from the folder which includes the History/ChangeLog file
#

require_relative 'json_pr_issue_base'

module HistoryNewRelease
  class << self
    include JsonPrIssueBase

    def run
      data = pr_commit_data_from_tag(ARGV[1])
      process_data data
    end

    def process_data(data)
      str = "## major.minor.patch / yyyy-mm-dd\n\n".dup
      LABELS.each do |t|
        str_label = ''.dup
        label = t.first
        desc  = t[1]
        entries = data.select do |hsh|
          !hsh.dig(:associatedPullRequests, :nodes).select { |pr|
            pr[:labels].include? label
          }.empty?
        end
        entries.each do |e|
          next if (pr = e.dig :associatedPullRequests, :nodes).empty?
          closes = pr.first[:bodyText][/(?:closes?|fixes) (#\d+)/i, 1]
          item = "  * #{e[:message][/.+/]}".dup
          if closes
            item.sub!(/\)\z/, ", #{closes})")
          end
          str_label << "#{item}\n"
        end
        str << "* #{desc}\n#{str_label}\n" unless str_label.empty?
      end
      puts str

      lbls = LABELS.map(&:first)
      bad_entries = data.select do |hsh|
        hsh.dig(:associatedPullRequests, :nodes).select { |pr|
          pr[:labels] & lbls
        }.empty?
      end
      unless bad_entries.empty?
        puts "\n─────────────────────────────────────── Commits without labels?"
        bad_entries.each do |bad|
          puts bad[:message][/.+/]
        end
      end
    end

    def pr_commit_data_from_tag(tag)
      str = <<~GRAPHQL
        query {
          repository(owner: "#{OWNER}", name: "#{REPO}") {
            object(expression: "#{tag}") {
              ... on Commit {
                committedDate
                pushedDate
              }
            }
          }
        }
      GRAPHQL
      hsh = nil
      http_connection do |http|
        date = run_request(http, str).dig :data, :repository, :object, :pushedDate
        hsh = run_request http, gql_query_commits_since(date)
      end
      data = hsh.dig :data, :repository, :ref, :target, :history, :nodes

      data.each do |d|
        prs = d.dig(:associatedPullRequests, :nodes)
        prs.each do |pr|
          temp = pr.dig :labels, :nodes
          temp = temp.map { |l| l[:name] }
          pr[:labels] = temp
        end
      end
      data
    end

    def gql_query_commits_since(date)
      str = <<~GRAPHQL
        query {
          repository(owner: "#{OWNER}", name: "#{REPO}") {
            ref(qualifiedName: "master") {
              target {
                ... on Commit {
                  history(first: 100, since: "#{date}") {
                    nodes {
                      oid
                      message
                      committedDate
                      associatedPullRequests(first: 10) {
                        nodes {
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
                          labels(first: 10) {
                            nodes {
                              name
                            }
                          }
                          bodyText
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL
      # debug
      # puts ''
      # str.lines.each_with_index { |l,i| puts "#{i.to_s.rjust 3}  #{l}" }
      str
    end
  end
end
HistoryNewRelease.run
