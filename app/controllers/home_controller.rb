class HomeController < ApplicationController
  before_filter :get_parameters, except: :index
  before_filter :check_logged_in, except: :index
  
  extend Memoist

  def index
  end
  
  def edit
    @content = get_files(@filename)[@filename]
  end  

  def message
    # Prepare a fork if we don't have permission to push
    unless github.repository(original_repo_path).permissions.push
      github.fork original_repo_path
    end
  end
  
  def commit    
    new_branch = commit_file(@filename, @content, @summary)
    @pr = open_pr("#{@current_user.username}:#{new_branch}", @branch, @summary, @description)
  end
  
  private
  
  def check_logged_in
    unless user_signed_in?
      session[:original_path] = request.path
      redirect_to root_path
    end
  end
  
  def get_parameters
    @owner = params[:owner]
    @repo = params[:repo]
    @branch = params[:branch]
    @filename = params[:filename] || "#{params[:path]}.#{params[:format]}"
    @format = params[:format]
    @content = params[:content]
    @summary = params[:summary]
    @description = params[:description]
  end

  def github
    @github = Octokit::Client.new(:access_token => session[:github_token])
  end

  def original_repo_path
    "#{@owner}/#{@repo}"
  end
  
  def user_repo_path
    "#{current_user.username}/#{@repo}"
  end
  
  def branch
    params[:branch]
  end
  
  GITHUB_REPO_REGEX = /github.com[:\/]([^\/]*)\/([^\.]*)/

  def latest_commit(branch_name)
    branch_data = github.branch user_repo_path, branch_name
    branch_data['commit']['sha']
  end
  memoize :latest_commit

  def tree(branch)
    t = github.tree(user_repo_path, branch, :recursive => true)
  end
  memoize :tree

  def blob_shas(branch, path)
    tree = tree(branch).tree
    Hash[tree.select{|x| x[:path] =~ /^#{path}$/ && x[:type] == 'blob'}.map{|x| [x.path, x.sha]}]
  end
  memoize :blob_shas
  
  def blob_content(sha)
    blob = github.blob user_repo_path, sha
    if blob['encoding'] == 'base64'
      Base64.decode64(blob['content'])
    else
      blob['content']
    end
  end
  memoize :blob_content
  

  def create_blob(content)
    github.create_blob user_repo_path, content, "utf-8"
  end

  def add_blob_to_tree(sha, filename)
    tree = tree @branch
    new_tree = github.create_tree user_repo_path, [{
      path: filename,
      mode: "100644",
      type: "blob",
      sha: sha
    }], base_tree: tree.sha
    new_tree.sha
  end

  def get_files(name)
    blobs = blob_shas(@branch, name)
    Hash[blobs.map{|x| [x[0], blob_content(x[1])]}]
  end

  def commit_sha(sha, message)
    parent = latest_commit(@branch)
    commit = github.create_commit user_repo_path, message, sha, [parent]
    commit.sha
  end
  
  def create_branch(name, sha)
    branch = github.create_reference user_repo_path, "heads/#{name}", sha
    branch.ref
  end

  def open_pr(head, base, title, description)
    pr = github.create_pull_request original_repo_path, base, head, title, description
    pr.html_url
  end
  
  def commit_file(name, content, message)    
    blob_sha = create_blob(content)
    tree_sha = add_blob_to_tree(blob_sha, name)
    commit_sha = commit_sha(tree_sha, message)
    create_branch(DateTime.now.to_s(:number), commit_sha)
  end

end
