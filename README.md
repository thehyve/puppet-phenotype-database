puppet-phenotype-database
=========================

Puppet module to install Phenotype Database application suite.

Basically an automation of the steps described in https://github.com/thehyve/GSCF/blob/master/INSTALLATION.md

Known issues:

With CentOS 5 the tomcat package step won't work.

CentOS 6 already has Tomcat 6 in its repository. This means the script should work.

Tested with Ubuntu 12.10