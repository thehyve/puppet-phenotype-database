# Custom type. Adds a new phenotypedbapp resource to the system.
#
# NB: Automation of : https://github.com/thehyve/GSCF/blob/master/INSTALLATION.md
#
# == Parameters:
#
# $databasename:: (optional, defaults to 'gscf-www') e.g. 'gscfwww'
# $dbusername:: (optional, defaults to 'gscf')
# $dbuserpassword:: password in ?? format
# $appurl:: url of the instance (e.g. ?)
# $adminuserpwd:: (optional, defaults to 'admin123') app admin password
# $modules:: (optional, defaults to ['sam', 'metabolomics'] ) array with list of extra modules to install
#
class phenotypedb::phenotypedbapp (
    $databasename     = 'gscfwww',
    $dbusername       = 'gscf',
    $dbuserpassword,
    $appurl,          /* include final slash */
    $vhost_servername,
    $adminuserpwd     = 'admin123',
    $modules          = ['sam','metabolomics'],
    $phenotypedbwarid = '17'
) {
    require phenotypedb
    require apache::mod::proxy_http
    include postgresql::server

    # make database instance in postgresql with name $databasename,
    # and add the user defined in $dbusername
    postgresql::db { $databasename:
        user     => $dbusername,
        password => $dbuserpassword,
    }

    # Change tomcat6 home to /home/tomcat6
    # This really should be changed to use tomcat::webapp, with a dedicated
    # user per application, as we for trait1 stuff
    # In fact, the tomcat class ensures that the tomcat6 sevice is disabled and
    # stopped, so every time the puppet agent is run, the application goes
    # down...
    # An additional problem is that the AJP connector has to be manually
    # activated; tomcat::webapp creates a server.xml with AJP already activated
    $tomcat_home = '/home/tomcat6'
    user { 'tomcat6':
        home       => $tomcat_home,
        ensure     => present,
        managehome => true
    }
    ->
    /* managehome doen't seem to create the home is the user already exists */
    file { $tomcat_home:
        ensure => directory,
        owner  => 'tomcat6',
        mode   => '755',
    }

    # =========Install GSCF===============================
    # download the phenotypedbapp .war
    # copy it to the right tomcat folder:
    #        root@nmcdsp:~# cd /var/lib/tomcat6/webapps/
    $download_dir   = "/var/lib/tomcat6/webapps"
    $downloaded_war = "${download_dir}/gscf-${phenotypedbwarid}.war"
    $download_url   = "https://trac.nbic.nl/gscf/downloads/${phenotypedbwarid}"

    exec { "download-phenotypedbapp-war":
        command => "/usr/bin/wget -O ${downloaded_war} ${download_url}",
        creates => $downloaded_war,
        timeout => 1200,
    }
    # set the correct rights:
    #   chown tomcat6.tomcat6 *.war;
    #   chmod gou+rx *.war
    file { $downloaded_war:
        owner  => 'tomcat6',
        mode   => '755',
    }

    apache::mod { 'rewrite': }
    ->
    apache::mod { 'proxy_balancer': }
    ->
    apache::mod { 'proxy_ajp': }
    ->
    apache::mod { 'proxy_html': }
    ->
    apache::vhost::proxy { 'gscf':
        servername => $vhost_servername,
        port       => 80,
        dest       => "balancer://gscf-cluster/gscf-$phenotypedbwarid/",
        #dest       => "http://localhost:8080/gscf-${phenotypedbwarid}",
        vhost_name => '*',
        template   => 'phenotypedb/gscf_site_apache.conf.erb',
    }

    # ========= Set up the application configuration =================

    file { "$tomcat_home/.gscf":
        ensure => 'directory',
        mode   => '700',
        owner  => 'tomcat6',
    }
    file { "$tomcat_home/.gscf/production.properties":
        ensure  => file,
        content => template("phenotypedb/production.properties"),
    }

  # install modules (sam, metabolomics, etc)
  # TODO
}
