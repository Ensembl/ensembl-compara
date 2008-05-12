package EnsEMBL::Web::Document::HTML::GlobalContext;

### Generates the global context navigation menu, used in dynamic pages

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub add_entry {
### a
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub active {
  my $self = shift;
  $self->{'_active'} = shift if @_;
  return $self->{'_active'};
}
sub entries {
### a
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render {
  my $self = shift;
  $self->print( '
      <dl id="global">' );
  foreach my $entry ( @{$self->entries} ) {
    my $name = $entry->{caption};
       $name = CGI::escapeHTML( $name );
    if( $entry->{'url'} ) {
      $name = sprintf( '<a href="%s">%s</a>', $entry->{'url'}, $name );
    }
    $self->printf( '
        <dd%s>%s</dd>', $entry->{'code'} eq $self->active  ? qq( class="active") : '', $name );
  }
  $self->print( '
      </dl>' );
}

return 1;
