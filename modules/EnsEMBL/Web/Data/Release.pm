package EnsEMBL::Web::Data::Release;

use strict;
use warnings;

use HTTP::Date 'str2time';
use POSIX      'strftime';

use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('ens_release');
__PACKAGE__->set_primary_key('release_id');

__PACKAGE__->add_queriable_fields(
  number  => 'varchar(5)',
  date    => 'date',
  archive => 'varchar(7)',
  online  => "enum('N','Y')"
);

__PACKAGE__->columns(TEMP => qw/full_date short_date shorter_date long_date/);

__PACKAGE__->has_many(news_items => 'EnsEMBL::Web::Data::NewsItem');
__PACKAGE__->has_many(species    => 'EnsEMBL::Web::Data::ReleaseSpecies');

__PACKAGE__->add_trigger(select => \&format_time);

sub format_time {
  my $self = shift;
  $self->full_date(strftime('%d %m %Y', localtime( str2time($self->date) )));
  $self->short_date(strftime('%b %Y', localtime( str2time($self->date) )));
  $self->shorter_date(strftime('%b%y', localtime( str2time($self->date) )));
  $self->long_date(strftime('%m %Y', localtime( str2time($self->date) )));
}

1;