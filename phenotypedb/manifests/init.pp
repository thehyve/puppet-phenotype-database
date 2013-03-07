# Custom class/aspect phenotypedb . 
# Puppet classes could also be called "roles" or "aspects" they
# describe one part of what makes up a system's identity. This class can be used to
# ensure the phenotypedb "aspect" is added/initialized on a server
#
# NB: Automation of : https://github.com/thehyve/GSCF/blob/master/INSTALLATION.md
#
# == Parameters:
#
# none
#
# == Actions: 
# 
# Prepares server by adding the necessary aspects to the system:
#
#  Apache Tomcat >= 6.x.x
#  Apache Webserver >= 2.x (+mod_proxy, +mod_rewrite UPDATE: mod_rewrite not needed ?)
#  PostgreSQL database server >= 8.4
#  Active internet connection (with change of code other options are to install a local instance of BioPortal or remove the link to BioPortal)
#
# Original command: 
#   install tomcat6 postgresql-8.4 apache2 libapache2-mod-proxy-html libapache2-mod-jk
#   
#
class phenotypedb ($localBioPortal = false) {

  # install apache aspect:
  class {'apache':  } 
  
  # install tomcat aspect:
  class {'tomcat':  } 
    
  # install postgresql aspect:
  class {'postgresql':  }   

  package { 'libnotify-bin':
      ensure => 'installed'
  }

  # if localBioPortal is true, install this locally as well:
  if $localBioPortal {
    class {'localbioportal': }
  }
  
  
}
