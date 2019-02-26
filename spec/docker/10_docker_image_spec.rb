require "docker_helper"

### DOCKER_IMAGE ###############################################################

describe "Docker image", :test => :docker_image do
  # Default Serverspec backend
  before(:each) { set :backend, :docker }

  ### DOCKER_IMAGE #############################################################

  describe docker_image(ENV["DOCKER_IMAGE"]) do
    # Execute Serverspec command locally
    before(:each) { set :backend, :exec }
    it { is_expected.to exist }
  end

  ### USERS ####################################################################

  describe "Users" do
    [
      # [user,                      uid,  primary_group]
      ["lighttpd",                  1000, "lighttpd"],
    ].each do |user, uid, primary_group|
      context user(user) do
        it { is_expected.to exist }
        it { is_expected.to have_uid(uid) } unless uid.nil?
        it { is_expected.to belong_to_primary_group(primary_group) } unless primary_group.nil?
      end
    end
  end

  ### GROUPS ###################################################################

  describe "Groups" do
    [
      # [group,                     gid]
      ["lighttpd",                  1000],
    ].each do |group, gid|
      context group(group) do
        it { is_expected.to exist }
        it { is_expected.to have_gid(gid) } unless gid.nil?
      end
    end
  end

  ### PACKAGES #################################################################

  describe "Packages" do
    [
      # [package,                   version,                    installer]
      "bash",
      "libressl",
      "lighttpd",
      "lighttpd-mod_auth",
    ].each do |package, version, installer|
      describe package(package) do
        it { is_expected.to be_installed }                        if installer.nil? && version.nil?
        it { is_expected.to be_installed.with_version(version) }  if installer.nil? && ! version.nil?
        it { is_expected.to be_installed.by(installer) }          if ! installer.nil? && version.nil?
        it { is_expected.to be_installed.by(installer).with_version(version) } if ! installer.nil? && ! version.nil?
      end
    end
  end

  ### FILES ####################################################################

  describe "Files" do
    [
      # [file,                                            mode, user,       group,      [expectations]]
      ["/docker-entrypoint.sh",                           755, "root",      "root",     [:be_file]],
      ["/etc/lighttpd/lighttpd.conf",                     644, "root",      "root",     [:be_file, :eq_sha256sum]],
      ["/etc/lighttpd/logs.conf",                         644, "root",      "root",     [:be_file, :eq_sha256sum]],
      ["/etc/lighttpd/server.conf",                       644, "root",      "root",     [:be_file, :eq_sha256sum]],
      ["/var/cache/lighttpd",                             750, "lighttpd",  "lighttpd", [:be_directory]],
      ["/var/lib/lighttpd",                               750, "lighttpd",  "lighttpd", [:be_directory]],
      ["/var/log/docker.log",                             600, "lighttpd",  "lighttpd", [:be_pipe]],
      ["/var/log/docker.err",                             600, "lighttpd",  "lighttpd", [:be_pipe]],
      ["/var/log/lighttpd",                               750, "lighttpd",  "lighttpd", [:be_directory]],
      ["/var/www",                                        755, "root",      "root",     [:be_directory]],
    ].each do |file, mode, user, group, expectations|
      expectations ||= []
      context file(file) do
        it { is_expected.to exist }
        it { is_expected.to be_file }       if expectations.include?(:be_file)
        it { is_expected.to be_pipe }       if expectations.include?(:be_pipe)
        it { is_expected.to be_directory }  if expectations.include?(:be_directory)
        it { is_expected.to be_mode(mode) } unless mode.nil?
        it { is_expected.to be_owned_by(user) } unless user.nil?
        it { is_expected.to be_grouped_into(group) } unless group.nil?
        its(:sha256sum) do
          is_expected.to eq(
              Digest::SHA256.file("rootfs/#{subject.name}").to_s
          )
        end if expectations.include?(:eq_sha256sum)
      end
    end
  end

  ##############################################################################

end

################################################################################
