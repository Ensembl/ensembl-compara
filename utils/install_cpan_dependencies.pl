#/usr/bin/perl

use strict;

use CPAN ();

# this simple cpan script will save a lot of effort in the CPAN install-fest for the webcode.
# N.B. It does not handle the LWP::Simple isssue for DAS. You will have to do this by hand.

my @list = (
    qw/
      Compress::Raw::Bzip2
      XML::LibXML
      RDF::Writer
      Date::Format
      Date::Parse
      IPC::Run
      MIME::Types
      Compress::Bzip2
      common::sense
      JSON
      JSON::XS
      GD
      Tree::DAG_Node
      Test::Warn
      SQL::Abstract
      Class::Accessor::Chained::Fast
      Data::Page
      DBD::SQLite
      UNIVERSAL::moniker
      Clone
      IO::WrapTie
      IO::Scalar
      Class::Trigger
      DBIx::ContextualFetch
      Ima::DBI
      Class::DBI
      String::CRC32
      Class::Singleton
      Params::Validate
      DateTime::TimeZone
      DateTime::Locale
      DateTime
      Digest::SHA1
      XML::XPath
      Class::Inspector
      Task::Weaken
      AppConfig
      Template
      XML::Parser::PerlSAX
      DateTime::Format::Mail
      DateTime::Format::W3CDTF
      Test::Manifest
      Cache::Memcached 
      CGI
      CGI::Ajax
      CGI::Session
      Class::Accessor
      Class::Data::Inheritable
      Class::DBI::Sweet
      Class::Std
      Class::Std::Utils
      Compress::Zlib
      Compress::Raw::Zlib
      Config::IniFiles Data::UUID
      DB_File
      DBI 
      Devel::StackTrace
      Digest::MD5
      Exception::Class
      File::Temp
      GD Hash::Merge
      HTML::Template
      Image::Size
      IO::String
      XML::LibXML
      List::MoreUtils
      Log::Log4perl
      LWP::Parallel::UserAgent
      Mail::Mailer
      Math::Bezier
      Number::Format
      OLE::Storage_Lite 
      Parse::RecDescent
      Cwd PDF::API2
      Readonly
      SOAP::Lite
      Spreadsheet::WriteExcel
      Storable
      Sub::Uplevel
      Sys::Hostname::Long
      Template::Plugin::Number::Format
      Test::Exception
      Test::Simple
      Time::HiRes
      version
      XML::DOM
      XML::Parser
      XML::RegExp
      XML::RSS XML::Simple
      GD::Text
      XML::RSS
      XML::Atom::Feed/
);


foreach my $mod (@list) {
    my $obj = CPAN::Shell->expand( 'Module', $mod );
    $obj->install;
}

