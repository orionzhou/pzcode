require(plyr)
require(dplyr)
require(ggplot2)
require(GenomicRanges)
require(grid)
require(reshape2)
require(RColorBrewer)
require(ape)
require(gridBase)
require(colorRamps)
source("Location.R")
source("comp.fun.R")

dirw = file.path(Sys.getenv("misc3"), "comp.og")
diro = file.path(Sys.getenv("misc3"), "comp.stat")

fi = file.path(dirw, "05.clu/32.tbl")
ti = read.table(fi, sep = "\t", header = T, as.is = T)
x = strsplit(ti$id, "-")
ti = cbind(ti, org = sapply(x, "[", 1), gid = sapply(x, "[", 2))

qnames = qnames_12
ti = ti[ti$org %in% c(tname,qnames),]

gb = group_by(ti, grp)
tr = dplyr::summarise(gb, size = length(unique(org)), org = org[1], rid = id[1])

##### plot pan-proteome AFS
tab1 = table(tr$size)
tab1 = tab1[names(tab1) != 1]
dt1 = data.frame(norg = as.numeric(names(tab1)), cnt = as.numeric(tab1), org = 'mixed', stringsAsFactors = F)

tab2 = table(tr$org[tr$size == 1])
tab2 = tab2[tab2 > 0]
dt2 = data.frame(norg = 1, cnt = as.numeric(tab2), org = names(tab2), stringsAsFactors = F)

to = rbind(dt1, dt2)

cols = c(brewer.pal(12, 'Set3'), brewer.pal(3, 'Set1')[1], 'gray30')
labs = orgs

to$org = factor(to$org, levels = c(orgs, 'mixed'))
to$norg = factor(to$norg, levels = sort(as.numeric(unique(to$norg))))
p1 = ggplot(to, aes(x = norg, y = cnt, fill = org, order = plyr:::desc(org))) +
  geom_bar(stat = 'identity', position = "stack", geom_params=list(width = 0.5)) +
  scale_fill_manual(name = "Accession-Specific", breaks = labs, labels = labs, values = cols, guide = guide_legend(ncol = 1, byrow = F, label.position = "right", direction = "vertical", title.theme = element_text(size = 8, angle = 0), label.theme = element_text(size = 8, angle = 0))) +
  scale_x_discrete(name = '# Sharing Accession') +
  scale_y_continuous(name = '# Gene Clusters', expand = c(0, 0), limits = c(0, 30100)) +
  theme_bw() +
  theme(axis.ticks.length = unit(0, 'lines'), axis.ticks.margin = unit(0.4, 'lines')) +
  theme(legend.position = c(0.3, 0.7), legend.background = element_rect(fill = 'white', colour = 'black', size = 0.3), legend.key = element_rect(fill = NA, colour = NA, size = 0), legend.key.size = unit(0.6, 'lines'), legend.margin = unit(0, "lines"), legend.title = element_text(size = 8, angle = 0), legend.text = element_text(size = 8, angle = 0)) +
  theme(plot.margin = unit(c(1,0,0,0), "lines")) +
  theme(axis.title.x = element_text(size = 9, angle = 0)) +
  theme(axis.title.y = element_text(size = 9, angle = 90)) +
  theme(axis.text.x = element_text(size = 8, colour = "blue")) +
  theme(axis.text.y = element_text(size = 8, colour = "brown", angle = 90, hjust = 1))

fp = sprintf("%s/73.pan.proteome.afs.pdf", diro)
ggsave(p1, filename = fp, width = 5, height = 5)

##### pan-proteome size
## run simulation
reps = 1:8
n_orgs = 1:(1+length(qnames_12))
tp = data.frame(rep = rep(reps, each = length(n_orgs)), 
  n_org = rep(n_orgs, length(rep)), core = NA, pan = NA)

for (rep in reps) {
  set.seed(rep * 100)
  orgs1 = c(tname, sample(qnames))
  for (i in 1:length(orgs1)) {
    tis = ti[ti$org %in% orgs1[1:i],]
    tp$pan[tp$rep == rep & tp$n_org == i] = length(unique(tis$grp))
    gb = dplyr::group_by(tis, grp)
    trs = dplyr::summarise(gb, size = length(unique(org)))
    tp$core[tp$rep == rep & tp$n_org == i] = sum(trs$size == i)
    cat(rep, orgs1[i], tp$core[i], tp$pan[i], "\n")
  }
}
fo = file.path(diro, "73.pan.proteome.size.tbl")
write.table(tp, fo, sep = "\t", row.names = F, col.names = T, quote = F, na = '')

## plot
fi = file.path(diro, "73.pan.proteome.size.tbl")
tp = read.table(fi, header = T, sep = "\t", as.is = T)

tp$rep = factor(tp$rep, levels = 1:max(tp$rep))
p2 = ggplot(tp) +
  geom_point(aes(x = n_org, y = pan), shape = 1, size = 1) +
  geom_point(aes(x = n_org, y = core), shape = 4, size = 1) +
  stat_smooth(aes(x = n_org, y = pan, col = 'a'), size = 0.3, se = F) +
  stat_smooth(aes(x = n_org, y = core, col = 'b'), size = 0.3, se = F) +
  scale_color_manual(name = "", labels = c('Pan-proteome', 'Core-proteome'), values = c("dodgerblue", "firebrick1")) +
  scale_x_continuous(name = '# Genomes Sequenced') +
  scale_y_continuous(name = '# Gene Clusters', expand = c(0, 0), limits = c(0, 110000)) + 
  theme_bw() +
  theme(axis.ticks.length = unit(0, 'lines'), axis.ticks.margin = unit(0.2, 'lines')) +
  theme(legend.position = c(0.15, 0.9), legend.background = element_rect(fill = 'white', colour = 'black', size = 0.3), legend.key = element_rect(fill = NA, colour = NA), legend.key.size = unit(1, 'lines'), legend.margin = unit(0, "line"), legend.title = element_blank(), legend.text = element_text(size = 8, angle = 0)) +
  theme(plot.margin = unit(c(1,1,0,0), "lines")) +
  theme(axis.title.x = element_text(size = 9, angle = 0)) +
  theme(axis.title.y = element_text(size = 9, angle = 90)) +
  theme(axis.text.x = element_text(size = 8, color = "blue")) +
  theme(axis.text.y = element_text(size = 8, color = "grey", angle = 90, hjust  = 0.5))
  
#fp = sprintf("%s/73.pan.proteome.size.pdf", diro)
#ggsave(p, filename = fp, width = 5, height = 5)

fo = sprintf("%s/73.pan.proteome.pdf", diro)
pdf(file = fo, width = 10, height = 5, bg = 'transparent')
numrow = 1; numcol = 2
grid.newpage()
pushViewport(viewport(layout = grid.layout(numrow, numcol)))
print(p1, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
print(p2, vp = viewport(layout.pos.row = 1, layout.pos.col = 2))

dco = data.frame(x = rep(1:numrow, each = numcol), y = rep(1:numcol, numrow), lab = LETTERS[1:(numrow*numcol)])
for (i in 1:nrow(dco)) {
  x = dco$x[i]; y = dco$y[i]; lab = dco$lab[i]
  grid.text(lab, x = 0, y = unit(1, 'npc'), just = c('left', 'top'), gp = gpar(col = "black", fontface = 2, fontsize = 20),
    vp = viewport(layout.pos.row = x, layout.pos.col = y))
}
dev.off()