=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Selenium::Test;

### Parent module for Ensembl Selenium tests

use strict;

use LWP::UserAgent;
use Time::HiRes;
use EnsEMBL::Selenium;
use Test::Exception;
use Test::More "no_plan";

my $TESTMORE_OUTPUT;

sub new {
  my($class, %args) = @_;

  return ('bug', 'Must supply a url') unless $args{url};
  
  my $self = {
    _url      => $args{url},
    _host     => $args{host},
    _port     => $args{port},
    _browser  => $args{browser},
    _ua       => $args{ua} || LWP::UserAgent->new(keep_alive => 5, env_proxy => 1),
    _conf     => $args{conf},
    _timeout  => $args{conf}{timeout} || 50000,
    _verbose  => $args{verbose},
    _species  => $args{species},
  };
    
  $self->{_sel} = EnsEMBL::Selenium->new( 
    _ua         => $self->{_ua},
    host        => $self->{_host},
    port        => $self->{_port},
    browser     => $self->{_browser},
    browser_url => $self->{_url},
  );

  bless $self, $class;
  
  # redirect Test::More output unless we're in verbose mode
  Test::More->builder->output(\$TESTMORE_OUTPUT) unless ($self->verbose);
    
  return $self;
}

sub url     {$_[0]->{_url}};
sub host    {$_[0]->{_host}};
sub port    {$_[0]->{_port}};
sub browser {$_[0]->{_browser}};
sub ua      {$_[0]->{_ua}};
sub sel     {$_[0]->{_sel}};
sub verbose {$_[0]->{_verbose}};
sub species {$_[0]->{_species}};


sub conf {
  my ($self, $key) = @_;
  return $self->{_conf}->{$key};
}

sub testmore_output {
  # test builder output (this will be empty if we are in verbose mode)
  return $TESTMORE_OUTPUT;
}

sub get_current_url {
### Gets the current URL in the window (to know which page is being tested)
  my $self = shift;
  my $location = $self->sel->get_location();
  return $location;
}

sub check_website {
### Check if the website to be tested is (still) up
  my $self = shift;
  
  my $url = $self->url;
  $self->sel->open("/");
  if ($self->sel->get_title eq "The Ensembl Genome Browser (development)") {
    return ('fail', "$url IS DOWN");
  }
}

sub set_species {
### Set the species in conf
 my ($self, $species) = @_; 
 $self->{'_species'} = $species;  
}

sub no_mirrors_redirect {
### Because the tests are currently run on a useast machine, accessing www.ensembl.org 
### on this machine will cause a redirect to useast. Hence we stop the redirect 
### (shouldn't be a problem to test-useast.ensembl.org as the link won't be here)
  my $self = shift;
  
  if($self->sel->is_text_present("You are being redirected to")) {
    $self->sel->open("/");
    $self->sel->click("link=here")
    and $self->sel->pause(5000);
  }
}

1;
