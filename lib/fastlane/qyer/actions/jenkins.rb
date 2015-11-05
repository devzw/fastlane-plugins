require 'net/http'
require 'json'
require 'time'


module Fastlane
  module Actions
    module SharedValues
      JENKINS_CHANGLOG = :JENKINS_CHANGLOG
      JENKINS_CVS_BRANCH = :JENKINS_CVS_BRANCH
      JENKINS_CVS_COMMIT = :JENKINS_CVS_COMMIT
      JENKINS_CI_URL = :JENKINS_CI_URL
    end

    class JenkinsAction < Action

      def self.run(params)
        fetch_changelog!
        fetch_jenkins_env!
      end

      def self.fetch_changelog!
        changes = []
        no = 1
        fetch_correct_changelog = false

        bid = ENV['BUILD_NUMBER'].to_i
        begin
          url = "#{ENV['JOB_URL']}/#{bid.to_s}/api/json"
          res = Net::HTTP.get_response(URI(url))
          if res.is_a?(Net::HTTPSuccess)
            json = JSON.parse(res.body)
            if json['result'] == 'SUCCESS'
              fetch_correct_changelog = true
            else
              json['changeSet']['items'].each do |commit|
                date = DateTime.parse(commit['date']).strftime("%Y-%m-%d %H:%m")
                changes.push("#{no.to_s}. #{commit['msg']} [#{date}]")
                no += 1
              end
            end
          end

          bid -= 1
        end until fetch_correct_changelog || bid <= 0

        if changes.size == 0
          last_success_commit = ENV['GIT_PREVIOUS_SUCCESSFUL_COMMIT']
          git_logs = `git log --pretty="format:%s - %cn [%ci]" #{last_success_commit}..HEAD`.strip.gsub(" +0800", "")
          changes = git_logs.split("\n")
        end

        changelog = changes.join("\n")
        Actions.lane_context[SharedValues::JENKINS_CHANGLOG] = changelog
        ENV[SharedValues::JENKINS_CHANGLOG.to_s] = changelog
      end

      def self.fetch_jenkins_env!
        branch = unless ENV['GIT_BRANCH'].to_s.empty?
          ENV['GIT_BRANCH'].include?('/') ? ENV['GIT_BRANCH'].split('/').last : ENV['GIT_BRANCH']
        else
          ENV['SVN_BRANCH']
        end

        Actions.lane_context[SharedValues::JENKINS_CVS_BRANCH] = branch
        ENV[SharedValues::JENKINS_CVS_BRANCH.to_s] = branch

        Actions.lane_context[SharedValues::JENKINS_CVS_COMMIT] = ENV['GIT_COMMIT']
        ENV[SharedValues::JENKINS_CVS_COMMIT.to_s] = ENV['GIT_COMMIT']

        Actions.lane_context[SharedValues::JENKINS_CI_URL] = ENV['BUILD_URL']
        ENV[SharedValues::JENKINS_CI_URL.to_s] = ENV['BUILD_URL']
      end

      def self.output
        [
          ['JENKINS_CHANGLOG', 'Current jenkins build changelog'],
          ['JENKINS_CVS_BRANCH', 'Current jenkins build CVS branch name'],
          ['JENKINS_CVS_COMMIT', 'Current jenkins build CVS last commit'],
          ['JENKINS_CI_URL', 'Current jenkins build url'],
        ]
      end

      def self.description
        'Jenkins utils tools'
      end

      def self.details
        "Jenkins utils tools like changelog, git details etc"
      end

      def self.author
        'icyleaf'
      end

      def self.is_supported?(platform)
        [:ios, :android, :mac].include? platform
      end
    end
  end
end