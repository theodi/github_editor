class HomeController < ApplicationController
  before_filter :get_parameters, except: :index

  
  extend Memoist

  def index
  end
  
  def edit
    @content = get_files(@filename)[@filename]
  end  

  def message
  end
  
  def commit
    new_branch = commit_file(@filename, @content, @summary)
    @pr = open_pr(new_branch, @branch, @summary, @description)
  end
  
  private
  
  def get_parameters
    @user = params[:user]
    @repo = params[:repo]
    @branch = params[:branch]
    @filename = params[:filename] || "#{params[:path]}.#{params[:format]}"
    @content = params[:content]
    @summary = params[:summary]
    @description = params[:description]
  end

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

  def latest_commit(branch_name)
    branch_data = github.branch repo, branch_name
    branch_data['commit']['sha']
  end
  memoize :latest_commit

  def tree(branch)
    t = github.tree(repo, branch, :recursive => true)
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
    github.create_blob repo, content, "utf-8"
  end

  def add_blob_to_tree(sha, filename)
    tree = tree @branch
    new_tree = github.create_tree repo, [{
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
    commit = github.create_commit repo, message, sha, [parent]
    commit.sha
  end
  
  def create_branch(name, sha)
    branch = github.create_reference repo, "heads/#{name}", sha
    branch.ref
  end

  def open_pr(head, base, title, description)
    pr = github.create_pull_request repo, base, head, title, description
    pr.html_url
  end
  
  def commit_file(name, content, message)    
    blob_sha = create_blob(content)
    tree_sha = add_blob_to_tree(blob_sha, name)
    commit_sha = commit_sha(tree_sha, message)
    create_branch(DateTime.now.to_s(:number), commit_sha)
  end

end
