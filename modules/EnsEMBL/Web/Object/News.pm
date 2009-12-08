package EnsEMBL::Web::Object::News;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Factory::News;
use EnsEMBL::Web::Data::NewsItem;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::Release;

use Carp qw/croak cluck/;

our @ISA = qw(EnsEMBL::Web::Object);

#------------------- ACCESSOR FUNCTIONS -----------------------------

sub adaptor     { return $_[0]->Obj->{'adaptor'};   }
sub release_id  { return $_[0]->Obj->{'release_id'};   }
sub releases    { return $_[0]->Obj->{'releases'};   }
sub all_cats    { return $_[0]->Obj->{'categories'};   }
sub all_spp     { return $_[0]->Obj->{'species'};   }

sub sp_array {
  my $self = shift;
  ## sort out array of chosen species
  my $all_spp = $self->all_spp;
  my @sp_array;
  if ($self->param('species')) {
    @sp_array = ($self->param('species'));
  } else { ## create based on name of directory
    my $sp_dir = $self->species;
    if ($sp_dir eq 'Multi') { ## make array of all species ids
      @sp_array = sort {$a <=> $b} keys %$all_spp;
    }
    else { ## look up species id from directory name
      my %rev_hash = reverse %$all_spp;
      @sp_array = ($rev_hash{$sp_dir});
    }
  }
  return \@sp_array; 
}

#------------------- DATABASE QUERIES -------------------------------

sub valid_spp   { 
  my $self = shift;
  my %species = map { $_->id => $_->name }
                  EnsEMBL::Web::Data::Species->search({
                    'releases.release_id' => $self->release_id
                  }); 
  return \%species;
}

sub current_spp   { 
  my $self = shift;
  my %species =  map { $_->id => $_->name }
                  EnsEMBL::Web::Data::Species->search({
                    'releases.release_id' => $self->species_defs->ENSEMBL_VERSION,
                  }); 
  return \%species;  
}

sub valid_rels   { 
  my $self = shift;
  my @releases;
  my @sp_array = @{$self->sp_array};
  if (scalar(@sp_array) == 1 && $sp_array[0]) {
    ## single species
    @releases = EnsEMBL::Web::Data::Release->search(
      { 'species' => $sp_array[0] },
      { order_by => 'release_id DESC' },
    );
  } else {
    ## in multi-species mode, all releases are valid    
    @releases = EnsEMBL::Web::Data::Release->search(
      { },
      { order_by => 'release_id DESC' },
    );
  }
  return @releases;  
}

sub generic_items { 
  my $self = shift;

  my @items = EnsEMBL::Web::Data::NewsItem->fetch_news_items(
    {
      news_category_id => $self->param('news_category_id'),
      release_id       => $self->release_id,
      status           => 'handed_over',
      species          => undef,
    }
  );

  return [ @items ];
}

sub species_items { 
  my $self = shift;

  my @items = EnsEMBL::Web::Data::NewsItem->fetch_news_items(
    {
      news_category_id     => $self->param('news_category_id'),
      release_id           => $self->release_id,
      status               => 'handed_over',
      species              => $self->sp_array,
    },
  );

  return [ @items ];
}

sub all_items { 
  my $self = shift;

  my @items = EnsEMBL::Web::Data::NewsItem->fetch_news_items(
    {
      news_category_id => $self->param('news_category_id'),
      status           => 'handed_over',
      release_id       => $self->release_id,
    },
  );

  return [ @items ];
}


1;
