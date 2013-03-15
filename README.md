puppet-phenotype-database
=========================

Puppet module to install Phenotype Database application suite.

Basically an automation of the steps described in https://github.com/thehyve/GSCF/blob/master/INSTALLATION.md

Module name: phenotypedb

Usage:

phenotypedb::phenotypedbapp { 'testinstance1': 
    databasename  => 'gscfwww1',
    dbusername  => 'gscf',
    dbuserpassword=> '3rfjdklsfj3234f',
    instancename => 'testinstance1',
    appurl    => 'http://puppet-test-gscf.thehyve.net/',
    vhost_servername => 'puppet-test-gscf.thehyve.net',
    vhost_serveraliases => 'puppet-test-gscf.thehyve.net',
    vhost_port => 80,
    adminuserpwd  => 'admiN123!',
    modules   => ['sam','metabolomics','proteomics'],
    system_user => 'phenotypetest1',
    number => 0,
    memory => '1024m',
}

Known issues:

With CentOS 5 the tomcat package step won't work.

CentOS 6 already has Tomcat 6 in its repository. This means the script should work.

Tested with Ubuntu 12.10