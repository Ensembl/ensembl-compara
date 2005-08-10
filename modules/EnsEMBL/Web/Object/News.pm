package EnsEMBL::Web::Object::News;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Factory::News;

our @ISA = qw(EnsEMBL::Web::Object);

sub items { return $_[0]->Obj->{'items'}; }
sub releases   { return $_[0]->Obj->{'releases'};   }
sub all_spp   { return $_[0]->Obj->{'all_spp'};   }
sub all_cats   { return $_[0]->Obj->{'all_cats'};   }

sub add_news_item {
    my $self = shift;
    my @items = @{$self->items};
    my $added = {
        'release'       => $self->param('release'),
        'title'         => $self->param('title'),
        'content'       => $self->param('content'),
        'news_cat_code' => $self->param('news_cat_code'),
        'species_code'  => $self->param('species_code'),
        'priority'      => $self->param('priority')
    };
    my $result = $self->EnsEMBL::Web::Factory::News::news_adaptor->add_news_item($added);
    return $result;
}

sub update_news_item {
    my $self = shift;
    my @items = @{$self->items};
    my $updated = {
        'news_item_id'  => $self->param('news_item_id'),
        'release'       => $self->param('release'),
        'title'         => $self->param('title'),
        'content'       => $self->param('content'),
        'news_cat_code' => $self->param('news_cat_code'),
        'species_code'  => $self->param('species_code'),
        'priority'      => $self->param('priority')
    };
    my $result = $self->EnsEMBL::Web::Factory::News::news_adaptor->update_news_item($updated);
    return $result;
}

1;
