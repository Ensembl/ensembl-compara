=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::Utils::FormatTree;

use strict;
use warnings;

use Data::Dumper;
use Carp;
#$::RD_HINT = 1;

# Grammar to parse $fmt
my $grammar = q(
{
    my @tokens;
    push @tokens, {}
}

hyphen      : "-"

has_parent  : "^"
{
    $tokens[-1]->{has_parent} = 1
}

or          : "|"

modifier_dot   : "."
{
    $tokens[-1]->{modifier} = "dot";
}
modifier_comma : ","
{
    $tokens[-1]->{modifier} = "comma";
}
modifier_underscore: "_"
{
    $tokens[-1]->{modifier} = "underscore";
}
modifier_upper : "^"
{
    $tokens[-1]->{upper} = 1;
}

string   : /[^%{}\"\(\)\,]+/i

number      : /[0-9]+/

Tag_condition : "," string ( "," string )(?)
{
    $tokens[-1]->{tag_condition} = $item[2];
    $tokens[-1]->{tag_value} = $item[3]->[0] if scalar(@{$item[3]});
}

Tag_reader   : "T(" string (Tag_condition)(?) ")"
{
    $tokens[-1]->{tag_name} = $item{string};
    "T";
}

Method_caller : "C(" string ( "," string )(s?) ")"
{
    $tokens[-1]->{method_name} = [$item[2], @{$item[3]}] ;
    "C";
}

Letter_code : "n" | "c" | "d" | "t" | "r" | "l" | "L" | "h" | "s" | "p" | "m" | "g" | "i" | "o" | "x" | "X" | "S" | "N" | "P" | "E" | Tag_reader | Method_caller

preliteral  : string
{
    $tokens[-1]->{ preliteral } = $item{string}
}

postliteral : string
{
    $tokens[-1]->{ postliteral } = $item{string}
}

Format      : /^/ Entry(s) /$/
{
    \@tokens
}

Entry       : (Token | literal)(s)

literal     : string
{
    push @tokens, {};
    $tokens[-1]->{literal} = $item{string};
    push @tokens, {};
}

Len_limit : number
{
    $tokens[-1]->{len_limit} = $item{number}
}

Token       : "%"  (Len_limit)(?) "{" (has_parent)(?) ('"' <skip: ''> preliteral '"')(?) Condition ('"' <skip: ''> postliteral '"')(?) "}"
{
    push @tokens, {}
}

Condition   : Code ( modifier_dot | modifier_comma | modifier_underscore )(?) (modifier_upper)(?)  ( or Letter_code )(s?)
{
    if (scalar @{$item[4]}) {
        $tokens[-1]->{alternatives} = join "", @{$item[4]}
    }
}

Code        : hyphen Letter_code
{
    $tokens[-1]->{place} = "Leaf";
    $tokens[-1]->{main} = $item{Letter_code}
}

Code        : Letter_code hyphen
{
    $tokens[-1]->{place} = "Internal";
    $tokens[-1]->{main} = $item{Letter_code}
}

Code        : Letter_code
{
    $tokens[-1]->{place} = "Both";
    $tokens[-1]->{main} = $item{Letter_code}
}
);

## Callbacks


## maybe we can use AUTOLOAD to populate most of these?

# C(name)
my $name_cb = sub {
    my ($self) = @_;
    if ($self->{tree}->can('node_name') && defined $self->{tree}->node_name) {
        return $self->{tree}->node_name;
    }
    return $self->{tree}->name;
};

my $distance_to_parent_cb = sub {
  my ($self) = @_;
  my $dtp = $self->{tree}->distance_to_parent()+0;
  return "$dtp";
};

# T(genbank common name)
my $genbank_common_name = sub {
  my ($self) = @_;
  return $self->{tree}->get_value_for_tag('genbank common name');
};

# T(ensembl timetree mya)
my $ensembl_timetree_mya_cb = sub {
  my ($self) = @_;
  return $self->{tree}->get_value_for_tag('ensembl timetree mya');
};

my $gdb_id_cb = sub {
  my ($self) = @_;
  if ($self->{tree}->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    return $self->{tree}->species_tree_node->genome_db_id;

  } elsif ($self->{tree}->isa('Bio::EnsEMBL::Compara::SpeciesTreeNode')) {
    return $self->{tree}->genome_db_id;

  } elsif ($self->{tree}->isa('Bio::EnsEMBL::Compara::NCBITaxon')) {
    return $self->{tree}->adaptor->db->get_GenomeDBAdaptor->fetch_all_by_taxon_id($self->{tree}->taxon_id)->[0]->dbID;
  }
};

# C(node_id)
my $node_id_cb = sub {  ## only if we are in a leaf? ... if ($self->{tree}->is_leaf);
  my ($self) = @_;
  return $self->{tree}->node_id;
};

# C(gene_member,display_label)
my $label_cb = sub { ## only if we are in a leaf? ... if ($self->{tree}->is_leaf);
  my ($self) = @_;
  my $display_label = $self->{tree}->gene_member->display_label;
  return $display_label;
};

# C(gene_member,display_label)
my $label_ext_cb = sub {
    my ($self) = @_;
    my $display_label = $self->{tree}->gene_member->display_label;
    if (!defined($display_label) || $display_label eq '') {
        my $display_xref = $self->{tree}->gene_member->get_Gene->display_xref;
        $display_label = $display_xref->display_id if (defined($display_xref));
    }    
    return $display_label;
};

# C(genome_db,short_name)
my $sp_short_name_cb = sub {
  my ($self) = @_;
  if (!defined $self->{tree}->genome_db) {
    return;
  }
  return $self->{tree}->genome_db->get_short_name;
};

my $transcriptid_cb = sub {
    my ($self) = @_;
    $self->{tree}->description =~ /Transcript:(\w+)/;
    return $1;
};

# C(gene_member,stable_id)
my $stable_id_cb = sub {  ## only if we are in a leaf?
  my ($self) = @_;
  return $self->{tree}->is_leaf ? $self->{tree}->gene_member->stable_id : undef;
};

# C(stable_id)
my $prot_id_cb = sub {
  my ($self) = @_;
  return $self->{tree}->is_leaf ? $self->{tree}->stable_id : undef;
};

# C(seq_member_id)
my $seq_member_id_cb = sub {
  my ($self) = @_;
  unless ($self->{tree}->can('seq_member_id')) {
      return;
  }
  return $self->{tree}->seq_member_id;
};

# C(taxon_id)
my $taxon_id_cb = sub {
  my ($self) = @_;
  if (not $self->{tree}->can('taxon_id') and $self->{tree}->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    return $self->{tree}->species_tree_node->taxon_id;
  }
  return $self->{tree}->taxon_id;
};

my $stn_id_cb = sub {
  my ($self) = @_;
  if ($self->{tree}->isa('Bio::EnsEMBL::Compara::SpeciesTreeNode')) {
      return $self->{tree}->node_id;
  } elsif ($self->{tree}->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
      return $self->{tree}->_species_tree_node_id;
  }
};

my $sp_name_cb = sub {
  my ($self) = @_;
  my $species_name;
  if ($self->{tree}->can('genome_db')) {
      $species_name = $self->{tree}->genome_db->name;
      return $species_name;
  } elsif ($self->{tree}->can('taxon_id')) {
      my $taxon_id = $self->{tree}->taxon_id();
      my $genome_db_adaptor = $self->{tree}->adaptor->db->get_GenomeDBAdaptor;
      my $genome_db = $genome_db_adaptor->fetch_all_by_taxon_id($taxon_id)->[0];
      return $genome_db ? $genome_db->name() : $taxon_id;
  }
  return undef;
};

# C(n_members)
my $n_members_cb = sub {
    my ($self) = @_;
    my $n_members;
    if ($self->{tree}->isa('Bio::EnsEMBL::Compara::CAFEGeneFamilyNode')) {
        return $self->{tree}->n_members();
    }
    return undef;
};

# C(p_value)
my $pvalue_cb = sub {
    my ($self) = @_;
    my $pval;
    if ($self->{tree}->isa('Bio::EnsEMBL::Compara::CAFEGeneFamilyNode')) {
        return $self->{tree}->pvalue()+0;
    }
    return undef;
};

my $empty_cb = sub {
    return '';
};

my $tag_cb = sub {
    my ($self, $token) = @_;
    my $value = $self->{tree}->get_value_for_tag($token->{tag_name});
    return $value unless exists $token->{tag_condition};
    return undef unless defined $value;
    return undef unless $value eq $token->{tag_condition};
    return $token->{tag_value} if exists $token->{tag_value};
    return $value;
};

my $method_cb = sub {
    my ($self, $token) = @_;
    my $value = $self->{tree};
    foreach my $method (@{$token->{method_name}}) {
        return undef unless defined $value;
        return undef unless $value->can($method);
        $value = $value->$method;
    }
    return $value;
};

my %callbacks = (
        'n' => $name_cb,
        'c' => $genbank_common_name,
        'd' => $distance_to_parent_cb,
        't' => $ensembl_timetree_mya_cb,
        'g' => $gdb_id_cb,
        'o' => $node_id_cb,
        'l' => $label_cb,
        'L' => $label_ext_cb,
        's' => $sp_short_name_cb,
        'i' => $stable_id_cb,
        'r' => $transcriptid_cb,
        'p' => $prot_id_cb,
        'm' => $seq_member_id_cb,
        'x' => $taxon_id_cb,
        'X' => $stn_id_cb,
        'S' => $sp_name_cb,
        'N' => $n_members_cb, # Used in cafe trees (number of members)
        'P' => $pvalue_cb, # Used in cafe trees (pvalue)
        'E' => $empty_cb, ## Implement the "Empty" option
        'T' => $tag_cb,
        'C' => $method_cb,
);


# Maybe leaves and internal nodes should be formatted different?
my %cache;
sub new {
    my ($class,$fmt) = @_;
    $fmt = "%{n}" unless (defined $fmt); # "full" by default
    return $cache{$fmt} if defined $cache{$fmt};
    
    my $obj = bless ({
            'fmt' => $fmt,
            'callbacks' => {%callbacks},
    }, $class);
    eval { require Parse::RecDescent };
    if ($@) {
        die "You need Parse::RecDescent installed to output a tree in newick format. Please install it from CPAN, or from your usual Perl distribution.\n";
    }
    eval {
        my $parser = Parse::RecDescent->new($grammar);
        my $tokens = $parser->Format($fmt);
        #print Dumper($tokens);
        croak "Format $fmt is not valid\n" unless (defined $tokens);
        my @tokens = grep {scalar keys %{$_} > 0} @$tokens;    ## Hacky... but shouldn't be needed anymore (just a pop)
        $obj->{tokens} = [@tokens];
    };
    if ($@) {
        die $@ if ($@ =~ /Parse::RecDescent/);
        die "Bad format : $fmt\n";
    }
    $cache{$fmt} = $obj;
    return $obj;
}

sub format_newick {
  my ($self, $tree) = @_;
  return $self->_internal_format_newick($tree);
}

sub _internal_format_newick {
    my ($self, $tree) = @_;
    my $newick = "";
    if ($tree->get_child_count()>0) {
        $newick .= "(";
        my $first_child = 1;
        for my $child (@{$tree->sorted_children}) {
            $newick .= "," unless ($first_child);
            $newick .= $self->_internal_format_newick($child);
            $first_child = 0;
        }
        $newick .= ")";
    }

    my $header = "";
    $self->{tree} = $tree;
    for my $token (@{$self->{tokens}}) {
        if (defined $token->{literal}) {
            $header .= $token->{literal}
        } elsif (($token->{place} eq "Leaf") && ($tree->is_leaf) ||
                ($token->{place} eq "Internal") && (! $tree->is_leaf) ||
                ($token->{place} eq "Both")) {
            next if (defined $token->{has_parent} && $token->{has_parent} == 1 && !$tree->parent);
            for my $item (split //,$token->{main}.($token->{alternatives} || '')) {  ## For "main" and "alternatives"
                die "Callback $item not defined\n" unless exists $self->{callbacks}{$item};
                my $itemstr = $self->{callbacks}{$item}->($self, $token);
                #print STDERR "ITEMSTR:$itemstr\n";exit;
                if (defined $itemstr) {
          #          print Dumper($itemstr);
          #          print Dumper($token);
                    my $modifier = {
                        '' => '',
                        'dot' => '.',
                        'underscore' => '_',
                    }->{$token->{modifier} || ''};

                    my $forbidden_char = $token->{modifier} ? '[ ,(:;)]' : '[,(:;)]';
                    $itemstr =~ s/^$forbidden_char+//;
                    $itemstr =~ s/$forbidden_char+$//;
                    $itemstr =~ s/$forbidden_char+/$modifier/g;

                    $itemstr = uc $itemstr if exists $token->{upper};

                    my $str_to_append = ($token->{preliteral} || '').$itemstr.($token->{postliteral} || '');
                    $str_to_append = substr($str_to_append, 0, $token->{len_limit}) if exists $token->{Len_limit};
                    $header .= $str_to_append;
                    last;
                }
            }
        }
    }
#  $header .= ":".$self->{callbacks}{d}->($self);
    return $newick.$header;
}


1;

### NEED TO BE UPDATED

# ++ A "format" is a regular string containing string literals and "tokens". Tokens are:
# %{n} --> then "name" of the node ($self->name)
# %{c} --> the common name ($self->get_value_for_tag('genbank common name'))
# %{d} --> gdb_id ($self->adaptor->db->get_GenomeDBAdaptor->fetch_all_by_taxon_id($self->taxon_id)->[0]->dbID)
# %{t} --> timetree ($self->get_value_for_tag('ensembl timetree mya')
# %{l} --> display_label ($self->gene_member->display_label)
# %{h} --> genome short name ($self->genome_db->get_short_name)
# %{s} --> stable_id ($self->gene_member->stable_id)
# %{p} --> peptide Member ($self->get_canonical_SeqMember->stable_id)
# %{t} --> taxon_id ($self->taxon_id)
# %{m} --> seq_member_id ($self->seq_member_id)
# %{g} --> genome_db name ($self->genome_db->name)
# %{i} --> node_id ($self->node_id)
# %{e} --> nothing (useful to include only regular characters, see below)

# ++ These "tokens" can be modified using the following rules:

# + Apply tokens only to leaves or internal nodes:
# %{n}  --> The token applies to nodes and leaves
# %{-n} --> The token applies only to leaves
# %{n-} --> The token applies only to internal nodes

# + Tokens can be applied conditionally:
# %{p|n} --> Give the "peptide_member_stable_id" or (if it is undefined), the name
# %{-p|n} --> Same as below, but only for leaves
# %{n|-p} --> Give the name, but for leaves give the peptide_id.

# + string literals can be inserted outside or inside tokens (the meaning is slightly different):
# _%{n} --> Put an underscore and the name.
# %{_n} --> Put an underscore and the name only if name is defined.
# %{_-e} --> Put an underscore only if you are in a leaf.

# + hyphens and closing brackets are not allowed (we can define a way to scape them).

# ++ Equivalences with existing formats:

# "full" --> '%{n};

# "full_common" --> '%{n}%{ -c}%{.-d}{_t-}' -- Reads: Print the name of the node, if you are in a leaf and its "common_name" is defined print a space and the "common_name". Then, if you are in a leaf and the "gdb_id" is defined, print a dot and the "gdb_id", print an underscore and the "ensembl timetree mya".

# "int_node_id" --> '%{-n}%{-I}'

# display_label_composite --> '%{-l_}%{n}%{_-e}%{-h}' -- Reads: If you are in a leaf and the "display label" is defined, print it followed by an underscore. Print the "name". If you are in a leaf node, print an underscore and the "genome short name".

# "gene_stable_id_composite" --> '%{-s_}%{n}{_e}%{-h}'

# "full_web" --> '%{n:-p}%{_-e}%{-h}%{_-e}%{-l} -- Reads: Print the name or the stable id of the peptide member if it you are in a leaf and it is defined. Then print an underscore if you are in a leaf. Print the genome short name if you are in a leaf. Print an underscore if you are in a leaf. Print the display label if you are in a leaf.

# Etc...


# M;

# PS: The specification of the format in EBNF could be something like this:

# Format = "'" { string_literal | Token } "'" .
# Token = "%{" [string_literal] Code [ ":" Code ] [string_literal] "}" .
# Code = [ "-"  ] Letter_code [ "-" ]
# Letter_code = [ "n" | "c" | "d" | "t" | "l" | "h" | "s" | "p" | "t" | "m" | "g" | "i" | "e" ] .
