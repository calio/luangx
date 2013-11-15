#!/usr/bin/env perl

use Getopt::Std;
use File::Temp qw/ tempdir /;
use File::Copy;

use strict;
use warnings;

my $PORT = int(rand(10000) + 10000);

sub usage()
{
    print "usage:\n";
}

sub make_dirs($) {
    my $root = shift;
    mkdir "$root/logs";
    mkdir "$root/conf";
}

sub make_conf($) {
    my $root = shift;

    my $conf = <<END;

worker_processes  1;

error_log  logs/error.log notice;
pid        logs/nginx.pid;

events {
    worker_connections  256;
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
            content_by_lua_file "$root/main.lua";
        }
    }
}

END

    open FILE, ">", "$root/conf/nginx.conf" or die "Can't open $root/conf/nginx.conf: $!";
    print FILE $conf;
    close FILE;
}

sub make_start_script($)
{
    my $root = shift;
    open FILE, ">", "$root/start-nginx.sh" or die "Can't open $root/start-nginx.sh: $!";

    print FILE <<'EOF';
nginx -c `pwd`\/conf\/nginx.conf -p `pwd`/
EOF
    close FILE;

    open FILE, ">", "$root/stop-nginx.sh" or die "Can't open $root/stop-nginx.sh: $!";
    print FILE <<'EOF';
kill `cat logs/nginx.pid `
EOF
    close FILE;

    chmod 0755, "$root/start-nginx.sh", "$root/stop-nginx.sh" or die "chmod failed: $!";
}

sub make_env($)
{
    my $base = shift;
    make_dirs($base);
    make_conf($base);
    make_start_script($base);
}

sub check_cmd($)
{
    my $cmd = shift;
    if ($cmd ne "run" && $cmd ne "make-env") {
        print "Unknown command: $cmd\n";
        usage();
        exit 1;
    }
}

sub prepare_lua_file($$)
{
    my ($luafile, $workdir) = @_;
    copy($luafile, "$workdir/main.lua");
}

sub start_nginx($)
{
    my $workdir = shift;
    chdir $workdir;

    `./start-nginx.sh`;
    my $pid = `cat logs/nginx.pid`;
    chomp $pid;

    return $pid;
}

sub run_file($) {
    my $luafile = shift;

    my $tmpdir = tempdir( CLEANUP => 1 );

    make_env($tmpdir);

    prepare_lua_file($luafile, $tmpdir);

    my $pid = start_nginx($tmpdir);

    my $res = `curl "localhost:$PORT/lua?a=1" 2>/dev/null`;
    print $res;

    open ERROR_LOG, "$tmpdir/logs/error.log" or die "Can't open $tmpdir/logs/error.log: $!";
    while (<ERROR_LOG>) {
        print;
    }
    close ERROR_LOG;

    kill $pid;
}

my $cmd = shift || "run";

check_cmd($cmd);

my %opts;
getopts('h', \%opts) or die "Usage: xxx";

my $luafile = shift;

if (!$luafile) {
    warn 'Missing lua file';
    usage();
}

if ($cmd eq "make-env") {
    make_env(".");
} elsif ($cmd eq "run") {
    run_file($luafile);
}
