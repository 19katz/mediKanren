# Ingesting a new Neo4j dump

Assuming `neo4j` is already stopped, convert a Robokop (or RTX) `X.dump` to CSV format via:

```
neo4j-admin load --from X.dump --database graph.db --force
neo4j start
cd YOUR-PATH-TO-NCATS-ROOT/ncats-translator/kgx
cp config-robokop.yml config.yml
time python3 neo4j_download.py
neo4j stop
```

Then follow the instructions in `mediKanren/biolink/README.md` for converting the CSVs to mediKanren format.

If CSVs are downloaded from a remote source, then after the CSVs are grouped in a directory, yet before running racket conversion scripts, first create a zip for backup:
```
cd data
zip -r semmed.csv.zip semmed
```

This isn't necessary for neo4j dumps because the dump is a reliable source (though doing so could still save the self-download time).  Remote sources are not reliable.

To backup the CSV->mediKanren work:
```
cd data
zip -r robokop.db.zip robokop
```


# Freeing up space once you are finished

If you installed neo4j using homebrew:

```
neo4j stop
rm -rf /usr/local/Cellar/neo4j/VERSION/libexec/data/databases/*
```

Supposedly this query should also work, but I get a memory error:

```
neo4j start
cypher-shell -u YOURUSERNAME -p YOURPASSWORD --non-interactive 'MATCH(n) DETACH DELETE n'
neo4j stop
```
