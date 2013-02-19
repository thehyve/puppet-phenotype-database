puppet-phenotype-database
=========================

Puppet module to install Phenotype Database application suite


Known issues:

With CentOS 5 the tomcat package won't work as yum can't find "tomcat6" package...
Workaround for now: 
http://wavded.tumblr.com/post/258713913/installing-tomcat-6-on-centos-5

CentOS 6 already has Tomcat 6 in its repository. This means the script should work.

Actually, more issues are there with CentOS 5, so this version of CentOS is NOT supported.