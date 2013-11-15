#!/bin/env perl

use Getopt::Std;

use strict;
use warnings;

sub make_dirs() {
    my $root = ".";
    mkdir "$root/logs";
    mkdir "$root/conf";
}

sub make_conf() {
    my $conf = <<'END';

worker_processes  1;

error_log  logs/error.log notice;
pid        logs/nginx.pid;

events {
    worker_connections  1024;
}

http {
    #include       mime.types;
    default_type  application/octet-stream;

    access_log  logs/access.log  combined;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    lua_package_path 'lib/?.lua;/usr/local/openresty/lualib/?.lua;;';
    lua_package_cpath ';;';

    server {
        listen       $PORT;
        server_name  localhost;


        location /hello {
            echo "hello";
        }

        location /lua {
            content_by_lua_file "$LUAFILE";
        }
    }
}

END

    print $conf;
}

sub make_start_script()
{
    open FILE, ">", "start-nginx.sh" or die "Can't open start-nginx.sh: $!";

    print ">start-nginx.sh" <<'EOF';
nginx -c `pwd`\/conf\/nginx.conf -p `pwd`/
EOF

}

my $cmd = shift;

print "Command is: ", $cmd;

my %opts;

sub usage()
{
    print "usage:\n";
}

getopts('h', \%opts) or die "Usage: xxx";

if ($cmd eq "make-env") {
    make_dirs();
    make_conf();
    make_start_script();
}

make_conf();
make_start_script();
