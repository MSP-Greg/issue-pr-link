#!/usr/bin/env ruby
# frozen_string_literal: true

# code by MSP-Greg
# argv[0] 'info json' file, argv[1] version/tag string
# run from the folder which includes the History/ChangeLog file
#

require_relative 'json_pr_issue_base'

module HistoryNewRelease
  YELLOW = "\e[93m"
  RED    = "\e[91m"
  GREEN  = "\e[92m"
  RESET  = "\e[0m"

  class << self
    include JsonPrIssueBase

    def run
      data, date = pr_commit_data_from_tag(ARGV[1])
      process_data data, date
    end

    def process_data(data, date)
      str = +"\nCommits/PR's after tag #{ARGV[1]}, dated #{date}:\n\n" \
            "## major.minor.patch / yyyy-mm-dd\n\n"

      LABELS.each do |t|
        str_label = ''.dup
        label = t.first
        desc  = t[1]
        entries = data.select do |hsh|
          !hsh.dig(:associatedPullRequests, :nodes).select { |pr|
            pr[:labels].include? label
          }.empty?
        end
        # only list PR's in the first category/label group they match
        data = data - entries
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
        hsh.dig(:associatedPullRequests, :nodes).empty? ||
        !hsh.dig(:associatedPullRequests, :nodes)[0].is_a?(Hash) ||
        (hsh.dig(:associatedPullRequests, :nodes)[0][:labels] & lbls).empty?
      end

      unless bad_entries.empty?
        puts "\n─────────────────────────────────────── Merged Commits/PR's not included in History"

        # remove 'waiting' labels
        bad_entries.each do |bad|
          nodes = bad.dig(:associatedPullRequests, :nodes)
          unless nodes.empty?
            nodes[0][:labels].reject! { |l| l.start_with? 'waiting' }
          end
        end

        # groups by label/type
        bad_by_type = bad_entries.group_by do |bad|
          nodes = bad.dig(:associatedPullRequests, :nodes)
          if nodes.empty?
            "#{YELLOW}Commit, No PR?#{RESET}"
          elsif nodes[0][:labels].empty?
            "#{YELLOW}No Labels#{RESET}"
          else
            "#{GREEN}\"#{nodes[0][:labels].join "\"  \""}\"#{RESET}"
          end
        end.sort

        str = +''
        bad_by_type.each do |label, commits|
          str << "#{label}\n"
          commits.each do |commit|
            str << "  #{commit[:committedDate][0,10]} #{commit[:message][/.+/]}\n"
          end
          str << "\n"
        end
        puts str
      end
    end

    def pr_commit_data_from_tag(tag)
      date = nil
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
        data_all = run_request(http, str)
        date = data_all.dig :data, :repository, :object, :committedDate
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
      [data, date]
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
