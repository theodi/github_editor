class HomeController < ApplicationController
  
  extend Memoist

  def index
  end
  
  def edit
    path = "#{params[:path]}.#{params[:format]}"
    @content = get_files(path)[path]
  end
  
  private
  
  def github
    @github = Octokit::Client.new(:access_token => session[:github_token])
  end
  
  def user
    params[:user]
  end
  
  def repo
    "#{user}/#{params[:repo]}"
  end
  
  def branch
    params[:branch]
  end
  
  GITHUB_REPO_REGEX = /github.com[:\/]([^\/]*)\/([^\.]*)/

  def default_branch
    github.repository(repo).default_branch
  end
  memoize :default_branch

  def latest_commit(branch_name)
    branch_data = github.repos.branch user, repo, branch_name
    branch_data['commit']['sha']
  end
  memoize :latest_commit

  def tree(branch)
    github.tree(repo, branch, :recursive => true)
  end
  memoize :tree

  def blob_shas(branch, path)
    tree = tree(branch).tree
    Hash[tree.select{|x| x[:path] =~ /^#{path}$/ && x[:type] == 'blob'}.map{|x| [x.path, x.sha]}]
  end
  memoize :blob_shas
  
  def blob_content(sha)
    blob = github.blob repo, sha
    if blob['encoding'] == 'base64'
      Base64.decode64(blob['content'])
    else
      blob['content']
    end
  end
  memoize :blob_content
  

  def create_blob(content)
    blob = github.git_data.blobs.create user, repo, "content" => content, "encoding" => "utf-8"
    blob['sha']
  end

  def add_blob_to_tree(sha, filename)
    tree = tree default_branch
    new_tree = github.git_data.trees.create user, repo, "base_tree" => tree['sha'], "tree" => [
      "path" => filename,
      "mode" => "100644",
      "type" => "blob",
      "sha" => sha
    ]
    new_tree['sha']
  end

  def get_files(name)
    blobs = blob_shas(default_branch, name)
    Hash[blobs.map{|x| [x[0], blob_content(x[1])]}]
  end

  def commit(sha)
    parent = latest_commit(default_branch)
    commit = github.git_data.commits.create user, repo, "message" => commit_message,
              "parents" => [parent],
              "tree" => sha
    commit['sha']
  end
  
  def create_branch(name, sha)
    branch = github.git_data.references.create user, repo, "ref" => "refs/heads/#{name}", "sha" => sha
    branch['ref']
  end

  def open_pr(head, base)
    github.pull_requests.create user, repo,
      "title" => pull_request_title,
      "body" => pull_request_body,
      "head" => head,
      "base" => base
  end
  

end
