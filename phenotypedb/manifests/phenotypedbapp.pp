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
define phenotypedb::phenotypedbapp (
  $databasename='gscfwww',
  $dbusername='gscf',
  $dbuserpassword,
  $appurl,
  $adminuserpwd='admin123',
  $modules=['sam','metabolomics'],
  $phenotypedbwarid='17'  
  ) 
{
  
	# make database instance in postgresql with name $databasename , and add the user defined in $dbusername
  class {'postgresql::server':  }  
  postgresql::db { $databasename:
    user => $dbusername,
    password => $dbuserpassword,
  }
    
  # ==========Create a .grails directory===============
  # Grails uses a cache folder, which should be created if the tomcat user cannot create it
  #    root@nmcdsp:~# 
  #    mkdir -p /usr/share/tomcat6/.grails;
  #    chown tomcat6 /usr/share/tomcat6/.grails;
  #    chmod -R gou+rwx /usr/share/tomcat6/.grails
  
  file { '/usr/share/tomcat6/.grails':
      ensure => 'directory',
      mode   => '777',
      owner  => 'tomcat6',
  }
	  
  # =========Install GSCF===============================  
	# download the phenotypedbapp .war
    # copy it to the right tomcat folder:  
    #        root@nmcdsp:~# cd /var/lib/tomcat6/webapps/
  $download_dir = "/var/lib/tomcat6/webapps"
  $downloaded_war = "${download_dir}/gscf-${phenotypedbwarid}.war"
  $download_url="https://trac.nbic.nl/gscf/downloads/${phenotypedbwarid}"
  
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

	  
  # install additional parts in  tomcat, apache,  with the correct configurations
	
  #   =========Set Up Apache to proxy / rewrite request===============
  #   
  #   As tomcat is running (by default) on 8080, it is not very professional to have your application run on 
  #   http://test.mysite.com:8080/gscf-0.6.6-nmcdsptest. Instead http://test.mysite.com is preferable. 
  #   Also it is convenient to be able to add load balancing functionality in case you expect high load. 
  #   Apache can solve these issues.
  $vhost_servername = "gscf.thehyve.net"
  $vhost_serveralias = "test.gscf.thehyve.net"
  $vhost_name = $vhost_serveralias
  
  apache::vhost::proxy { $vhost_name:
      servername => $vhost_servername,
      port       => 80,
      dest       => "http://localhost:8080/gscf-${phenotypedbwarid}",
      vhost_name => $vhost_name,
  }
    
  # this file is needed anyway given other settings are there (e.g. the balancer settings)
  file { '/etc/apache2/sites-available/gscf_site_apache.conf':
      ensure  => file,
      content => template("phenotypedb/gscf_site_apache.conf"),
  }
  # TODO - check for the correct file...conf
  
  
  # ========= Set up the application configuration =================
    
  file { '/usr/share/tomcat6/.gscf':
      ensure => 'directory',
      mode   => '777',
      owner  => 'tomcat6',
  }
  file { '/usr/share/tomcat6/.gscf/production.properties':
      ensure  => file,
      content => template("phenotypedb/production.properties"),
      require => File['/usr/share/tomcat6/.gscf']
  }
      
         
	# install modules (sam, metabolomics, etc)
  # TODO
  
}