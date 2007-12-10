package EnsEMBL::Web::Configuration::Domain;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Configuration;

our @ISA = qw(EnsEMBL::Web::Configuration);

sub domainview {
  my $self   = shift;
  my $panel1 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "info$self->{flag}",
    'caption' => 'Interpro Domain '.$self->{object}->domainAcc,
    'object'  => $self->{'object'}
  );
  $panel1->add_components(qw(
    name     EnsEMBL::Web::Component::Domain::name
    location EnsEMBL::Web::Component::Domain::karyotype_image
    synonyms EnsEMBL::Web::Component::Domain::interpro_link
  ));
  $self->initialize_zmenu_javascript;
  $self->{page}->content->add_panel( $panel1 );

  my $panel2 = new EnsEMBL::Web::Document::Panel::SpreadSheet(
    'code'    => "loc$self->{flag}",
    'caption' => "Location of Ensembl genes containing domain ".$self->{object}->domainAcc,
    'cacheable' => 'yes',
    'cache_type' => 'domaintable',
    'cache_filename' => $self->{'object'}->species.'-'.$self->{'object'}->domainAcc.'.table',
    'object'  => $self->{object},
    'status'  => 'panel_table',
    'params'  => { 'domain' => $self->{'object'}->domainAcc },
    'null_data' => '<p>There are no Ensembl genes with this domain</p>'
  );
  $panel2->add_components( qw(genes EnsEMBL::Web::Component::Domain::spreadsheet_geneTable) );

  $self->{page}->content->add_panel( $panel2 );
}

sub context_menu {
  my $self = shift;
  $self->{page}->menu->add_block( "domain$self->{flag}", 'bulleted',
                                  $self->{object}->domainAcc );
  $self->add_entry( "domain$self->{flag}", 'code' => 'domaindesc', 'text' => $self->{object}->domainDesc );
  $self->add_entry( "domain$self->{flag}", 'code' => 'domaininfo', 'text' => "Domain info.",
                                  'href' => "/@{[$self->{object}->species]}/domainview?domainentry=".$self->{object}->domainAcc );
  $self->add_entry( "domain$self->{flag}", 'code' => 'mart', 'icon' => '/img/biomarticon.gif' ,
    'text' => 'Gene List', 'title' => 'BioMart: Gene list',
    'href' => "/@{[$self->{object}->species]}/martlink?type=domain;domain_id=".$self->{object}->domainAcc );

}

1;
