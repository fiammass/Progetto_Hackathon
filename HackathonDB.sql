-- File di creazione completa del database

-- 1. Tabella base senza dipendenze
CREATE TABLE IF NOT EXISTS Utente (
    username VARCHAR(30) PRIMARY KEY,
    nome VARCHAR(30) NOT NULL,
    cognome VARCHAR(30) NOT NULL,
    password VARCHAR(100) NOT NULL
);

-- 2. Tabelle che dipendono da Utente
CREATE TABLE IF NOT EXISTS Organizzatore (
    id_organizzatore SERIAL PRIMARY KEY,
    username VARCHAR(30) NOT NULL,
    FOREIGN KEY (username) REFERENCES Utente(username) 
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Partecipante (
    id_partecipante SERIAL PRIMARY KEY,
    username VARCHAR(30) NOT NULL,
    FOREIGN KEY (username) REFERENCES Utente(username)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Giudice (
    id_giudice SERIAL PRIMARY KEY,
    username VARCHAR(30) NOT NULL,
    FOREIGN KEY (username) REFERENCES Utente(username) 
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- 3. Tabelle che dipendono da Organizzatore
CREATE TABLE IF NOT EXISTS Hackathon (
    id_hackathon SERIAL PRIMARY KEY,
    titolo VARCHAR(50) NOT NULL,
    sede VARCHAR(30) NOT NULL,
    durata INT NOT NULL,
    data_inizio DATE NOT NULL,
    data_fine DATE NOT NULL,
    descrizione_problema TEXT DEFAULT 'Descrizione assente.',
    data_apertura_iscrizioni DATE NOT NULL,
    data_chiusura_iscrizioni DATE NOT NULL,
    max_iscritti INT NOT NULL,
    max_dim_team INT NOT NULL,
    id_organizzatore INT NOT NULL DEFAULT 0,
    FOREIGN KEY (id_organizzatore) REFERENCES Organizzatore(id_organizzatore)
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT,
    CONSTRAINT durata_positiva CHECK (durata > 0),                /* [1] */
    CONSTRAINT date_corrette CHECK (                              /* [2] */
        (data_apertura_iscrizioni < data_chiusura_iscrizioni)         
        AND (data_chiusura_iscrizioni <= data_inizio)                 
        AND (data_inizio < data_fine) ),
    CONSTRAINT max_iscritti_minimo CHECK (max_iscritti > 1),      /* [3] */
    CONSTRAINT max_dim_team_minima CHECK (max_dim_team > 0),      /* [4] */
    CONSTRAINT chiave_naturale UNIQUE (titolo, sede)              /* [5] */
);

-- 4. Tabelle che dipendono da Hackathon
CREATE TABLE IF NOT EXISTS Team (
    id_team SERIAL PRIMARY KEY,
    nome VARCHAR(20) NOT NULL,
    numero_membri INT NOT NULL,
    id_hackathon INT NOT NULL,
    FOREIGN KEY (id_hackathon) REFERENCES Hackathon(id_hackathon)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT membri_positivi CHECK (numero_membri > 0)          /* [6] */
);

-- 5. Tabelle che dipendono da Team
CREATE TABLE IF NOT EXISTS Documento (
    id_documento SERIAL PRIMARY KEY,
    commento TEXT DEFAULT 'Commento assente.',
    contenuto TEXT NOT NULL,
    titolo VARCHAR(50) NOT NULL,
    id_team INT NOT NULL,
    FOREIGN KEY (id_team) REFERENCES Team(id_team)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- 6. Domini per gli attributi
CREATE DOMAIN dominio_voto AS INT
    CONSTRAINT range CHECK (VALUE BETWEEN 0 AND 10)               /* [7] */              
;

-- 7. Tabelle di Relazione
CREATE TABLE IF NOT EXISTS Registrazione (
    id_partecipante INT NOT NULL DEFAULT 0,
    id_hackathon INT NOT NULL,
    data DATE NOT NULL,
    PRIMARY KEY (id_partecipante, id_hackathon),
    FOREIGN KEY (id_partecipante) REFERENCES Partecipante(id_partecipante) 
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT,
    FOREIGN KEY (id_hackathon) REFERENCES Hackathon(id_hackathon) 
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Partecipazione (
    id_team INT NOT NULL,
    id_partecipante INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id_team, id_partecipante),
    FOREIGN KEY (id_team) REFERENCES Team(id_team)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    FOREIGN KEY (id_partecipante) REFERENCES Partecipante(id_partecipante) 
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT
);

CREATE TABLE IF NOT EXISTS Esaminazione (
    id_giudice INT NOT NULL DEFAULT 0,
    id_documento INT NOT NULL,
    PRIMARY KEY (id_giudice, id_documento),
    FOREIGN KEY (id_giudice) REFERENCES Giudice(id_giudice) 
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT,
    FOREIGN KEY (id_documento) REFERENCES Documento(id_documento) 
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Votazione (
    id_giudice INT NOT NULL DEFAULT 0,
    id_team INT NOT NULL,
    voto dominio_voto NOT NULL,
    PRIMARY KEY (id_giudice, id_team),
    FOREIGN KEY (id_giudice) REFERENCES Giudice(id_giudice)
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT,
    FOREIGN KEY (id_team) REFERENCES Team(id_team) 
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Selezione (
    id_hackathon INT NOT NULL,
    id_organizzatore INT NOT NULL DEFAULT 0,
    id_giudice INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id_hackathon, id_organizzatore, id_giudice),
    FOREIGN KEY (id_hackathon) REFERENCES Hackathon(id_hackathon)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    FOREIGN KEY (id_organizzatore) REFERENCES Organizzatore(id_organizzatore) 
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT,
    FOREIGN KEY (id_giudice) REFERENCES Giudice(id_giudice) 
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT
);

-- Procedura per il popolamento completo del database
CREATE OR REPLACE PROCEDURE popola_database()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Variabili per memorizzare gli ID generati
    org_id INT;
    part_id INT;
    giud_id INT;
    hack_id INT;
    team_id INT;
    doc_id INT;
    
    -- Array per memorizzare tutti gli ID
    org_ids INT[] := '{}';
    part_ids INT[] := '{}';
    giud_ids INT[] := '{}';
    hack_ids INT[] := '{}';
    team_ids INT[] := '{}';
    doc_ids INT[] := '{}';
    
    -- Contatori
    i INT;
    j INT;
    temp_row RECORD;
BEGIN
    -- 1. Popolamento tabella Utente
    RAISE NOTICE 'Popolamento tabella Utente...';
    -- Utente fantoccio
    INSERT INTO Utente (username, nome, cognome, password) VALUES
    ('username', 'Utente', 'inesistente', 'password');
    INSERT INTO Partecipante (id_partecipante, username) VALUES
    (0, 'username');
    INSERT INTO Organizzatore (id_organizzatore, username) VALUES
    (0, 'username');
    INSERT INTO Giudice (id_giudice, username) VALUES
    (0, 'username');
    
    INSERT INTO Utente (username, nome, cognome, password) VALUES
    -- Organizzatori
    ('mario.rossi', 'Mario', 'Rossi', 'hashed_password_1'),
    ('luca.bianchi', 'Luca', 'Bianchi', 'hashed_password_2'),
    ('anna.verdi', 'Anna', 'Verdi', 'hashed_password_3'),
    
    -- Partecipanti
    ('giovanni.neri', 'Giovanni', 'Neri', 'hashed_password_4'),
    ('sara.russo', 'Sara', 'Russo', 'hashed_password_5'),
    ('marco.ferrari', 'Marco', 'Ferrari', 'hashed_password_6'),
    ('elena.conti', 'Elena', 'Conti', 'hashed_password_7'),
    ('andrea.romano', 'Andrea', 'Romano', 'hashed_password_8'),
    ('chiara.gallo', 'Chiara', 'Gallo', 'hashed_password_9'),
    ('francesco.costa', 'Francesco', 'Costa', 'hashed_password_10'),
    ('laura.mancini', 'Laura', 'Mancini', 'hashed_password_11'),
    
    -- Giudici
    ('prof.smith', 'John', 'Smith', 'hashed_password_12'),
    ('dott.jones', 'Robert', 'Jones', 'hashed_password_13'),
    ('ing.wilson', 'David', 'Wilson', 'hashed_password_14');

    -- 2. Popolamento tabelle derivate da Utente
    RAISE NOTICE 'Popolamento tabelle Organizzatore...';
    -- Organizzatori (uno alla volta)
    INSERT INTO Organizzatore (username) VALUES ('mario.rossi') RETURNING id_organizzatore INTO org_id;
    org_ids := array_append(org_ids, org_id);
    
    INSERT INTO Organizzatore (username) VALUES ('luca.bianchi') RETURNING id_organizzatore INTO org_id;
    org_ids := array_append(org_ids, org_id);
    
    INSERT INTO Organizzatore (username) VALUES ('anna.verdi') RETURNING id_organizzatore INTO org_id;
    org_ids := array_append(org_ids, org_id);

    RAISE NOTICE 'Popolamento tabelle Partecipante...';
    -- Partecipanti (uno alla volta)
    INSERT INTO Partecipante (username) VALUES ('giovanni.neri') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);
    
    INSERT INTO Partecipante (username) VALUES ('sara.russo') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);
    
    INSERT INTO Partecipante (username) VALUES ('marco.ferrari') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);
    
    INSERT INTO Partecipante (username) VALUES ('elena.conti') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);
    
    INSERT INTO Partecipante (username) VALUES ('andrea.romano') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);
    
    INSERT INTO Partecipante (username) VALUES ('chiara.gallo') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);
    
    INSERT INTO Partecipante (username) VALUES ('francesco.costa') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);
    
    INSERT INTO Partecipante (username) VALUES ('laura.mancini') RETURNING id_partecipante INTO part_id;
    part_ids := array_append(part_ids, part_id);

    RAISE NOTICE 'Popolamento tabelle Giudice...';
    -- Giudici (uno alla volta)
    INSERT INTO Giudice (username) VALUES ('prof.smith') RETURNING id_giudice INTO giud_id;
    giud_ids := array_append(giud_ids, giud_id);
    
    INSERT INTO Giudice (username) VALUES ('dott.jones') RETURNING id_giudice INTO giud_id;
    giud_ids := array_append(giud_ids, giud_id);
    
    INSERT INTO Giudice (username) VALUES ('ing.wilson') RETURNING id_giudice INTO giud_id;
    giud_ids := array_append(giud_ids, giud_id);

    -- 3. Popolamento tabella Hackathon
    RAISE NOTICE 'Popolamento tabella Hackathon...';
    INSERT INTO Hackathon (
        titolo, sede, durata, data_inizio, data_fine, 
        descrizione_problema, data_apertura_iscrizioni, 
        data_chiusura_iscrizioni, max_iscritti, max_dim_team, id_organizzatore
    ) VALUES (
        'Hackathon Innovazione 2024', 'Milano', 3, 
        '2024-06-15', '2024-06-17',
        'Sviluppare soluzioni innovative per la mobilita'' sostenibile in ambito urbano',
        '2024-05-01', '2024-06-10', 100, 5, org_ids[1]
    ) RETURNING id_hackathon INTO hack_id;
    hack_ids := array_append(hack_ids, hack_id);
    
    INSERT INTO Hackathon (
        titolo, sede, durata, data_inizio, data_fine, 
        descrizione_problema, data_apertura_iscrizioni, 
        data_chiusura_iscrizioni, max_iscritti, max_dim_team, id_organizzatore
    ) VALUES (
        'Tech Challenge Roma', 'Roma', 2,
        '2024-07-20', '2024-07-21',
        'Creare applicazioni per migliorare l''esperienza turistica nella città eterna',
        '2024-06-01', '2024-07-15', 80, 4, org_ids[2]
    ) RETURNING id_hackathon INTO hack_id;
    hack_ids := array_append(hack_ids, hack_id);
    
    INSERT INTO Hackathon (
        titolo, sede, durata, data_inizio, data_fine, 
        descrizione_problema, data_apertura_iscrizioni, 
        data_chiusura_iscrizioni, max_iscritti, max_dim_team, id_organizzatore
    ) VALUES (
        'Green Coding Napoli', 'Napoli', 2,
        '2024-08-10', '2024-08-11',
        'Sviluppare software per il monitoraggio e riduzione dell''impatto ambientale',
        '2024-07-01', '2024-08-05', 60, 3, org_ids[3]
    ) RETURNING id_hackathon INTO hack_id;
    hack_ids := array_append(hack_ids, hack_id);

    -- 4. Popolamento tabella Team
    RAISE NOTICE 'Popolamento tabella Team...';
    -- Team per Hackathon 1
    INSERT INTO Team (nome, numero_membri, id_hackathon ) VALUES
    ('InnovationSquad', 3, hack_ids[1]) RETURNING id_team INTO team_id;
    team_ids := array_append(team_ids, team_id);
    
    INSERT INTO Team (nome, numero_membri, id_hackathon) VALUES
    ('TechPioneers', 3, hack_ids[1]) RETURNING id_team INTO team_id;
    team_ids := array_append(team_ids, team_id);
    
    INSERT INTO Team (nome, numero_membri, id_hackathon) VALUES
    ('GreenMovers', 2, hack_ids[1]) RETURNING id_team INTO team_id;
    team_ids := array_append(team_ids, team_id);
    
    -- Team per Hackathon 2
    INSERT INTO Team (nome, numero_membri, id_hackathon) VALUES
    ('RomanCoders', 3, hack_ids[2]) RETURNING id_team INTO team_id;
    team_ids := array_append(team_ids, team_id);
    
    INSERT INTO Team (nome, numero_membri, id_hackathon) VALUES
    ('AppExplorers', 2, hack_ids[2]) RETURNING id_team INTO team_id;
    team_ids := array_append(team_ids, team_id);
    
    -- Team per Hackathon 3
    INSERT INTO Team (nome, numero_membri, id_hackathon) VALUES
    ('EcoDevelopers', 3, hack_ids[3]) RETURNING id_team INTO team_id;
    team_ids := array_append(team_ids, team_id);

    INSERT INTO Team (nome, numero_membri, id_hackathon) VALUES
    ('TopTechs', 2, hack_ids[3]) RETURNING id_team INTO team_id;
    team_ids := array_append(team_ids, team_id);

    -- 5. Popolamento tabella Documento
    RAISE NOTICE 'Popolamento tabella Documento...';
    -- Documenti per Team 1
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Documento preliminare valido', 'Contenuto progetto mobilità sostenibile', 'Progetto Mobilità 4.0', team_ids[1])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);
    
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Aggiornamento design eccellente', 'Nuove specifiche tecniche', 'Design System v2', team_ids[1])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);
    
    -- Documenti per Team 2
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Analisi requisiti formale e corretta', 'Requisiti sistema di trasporto', 'Analisi Requisiti', team_ids[2])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);
    
    -- Documenti per Team 3
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Proposta iniziale ottima', 'Idee per mobilità green', 'Brainstorming Results', team_ids[3])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);
    
    -- Documenti per Team 4
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Idea innovativa', 'Specifiche app turistica Roma', 'App Roma Guide', team_ids[4])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);
    
    -- Documenti per Team 5
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Documentazione API ricca', 'API per servizi turistici', 'API Documentation', team_ids[5])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);
    
    -- Documenti per Team 6
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Valido approccio', 'Analisi impatto ambientale', 'Sustainability Report', team_ids[6])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);

    -- Documenti per Team 7
    INSERT INTO Documento (commento, contenuto, titolo, id_team) VALUES
    ('Funzionante e interessante', 'Rilievi tramite automi e sensori', 'Analisi particellare', team_ids[7])
    RETURNING id_documento INTO doc_id;
    doc_ids := array_append(doc_ids, doc_id);

    -- 6. Popolamento tabella Registrazione
    RAISE NOTICE 'Popolamento tabella Registrazione...';
    -- Registrazioni per Hackathon 1
    INSERT INTO Registrazione (id_partecipante, id_hackathon, data) VALUES
    (part_ids[1], hack_ids[1], '2024-05-02'),
    (part_ids[2], hack_ids[1], '2024-05-03'),
    (part_ids[3], hack_ids[1], '2024-05-05'),
    (part_ids[4], hack_ids[1], '2024-05-10'),
    (part_ids[5], hack_ids[1], '2024-05-15'),
    (part_ids[6], hack_ids[1], '2024-05-20'),
    (part_ids[7], hack_ids[1], '2024-05-25'),
    (part_ids[8], hack_ids[1], '2024-06-01');
    
    -- Registrazioni per Hackathon 2
    INSERT INTO Registrazione (id_partecipante, id_hackathon, data) VALUES
    (part_ids[2], hack_ids[2], '2024-06-02'),
    (part_ids[3], hack_ids[2], '2024-06-05'),
    (part_ids[4], hack_ids[2], '2024-06-10'),
    (part_ids[5], hack_ids[2], '2024-06-12'),
    (part_ids[6], hack_ids[2], '2024-06-15');
    
    -- Registrazioni per Hackathon 3
    INSERT INTO Registrazione (id_partecipante, id_hackathon, data) VALUES
    (part_ids[7], hack_ids[3], '2024-07-02'),
    (part_ids[8], hack_ids[3], '2024-07-05'),
    (part_ids[1], hack_ids[3], '2024-07-10'),
    (part_ids[2], hack_ids[3], '2024-07-20'),
    (part_ids[3], hack_ids[3], '2024-08-01');

    -- 7. Popolamento tabella Partecipazione
    RAISE NOTICE 'Popolamento tabella Partecipazione...';
    -- Team 1: InnovationSquad (3 membri)
    INSERT INTO Partecipazione (id_team, id_partecipante) VALUES
    (team_ids[1], part_ids[1]),
    (team_ids[1], part_ids[2]),
    (team_ids[1], part_ids[3]);
    
    -- Team 2: TechPioneers (4 membri)
    INSERT INTO Partecipazione (id_team, id_partecipante) VALUES
    (team_ids[2], part_ids[4]),
    (team_ids[2], part_ids[5]),
    (team_ids[2], part_ids[6]);
    
    -- Team 3: GreenMovers (2 membri)
    INSERT INTO Partecipazione (id_team, id_partecipante) VALUES
    (team_ids[2], part_ids[7]),
    (team_ids[3], part_ids[8]);
    
    -- Team 4: RomanCoders (3 membri)
    INSERT INTO Partecipazione (id_team, id_partecipante) VALUES
    (team_ids[4], part_ids[2]),
    (team_ids[4], part_ids[3]),
    (team_ids[4], part_ids[4]);
    
    -- Team 5: AppExplorers (2 membri)
    INSERT INTO Partecipazione (id_team, id_partecipante) VALUES
    (team_ids[5], part_ids[5]),
    (team_ids[5], part_ids[6]);
    
    -- Team 6: EcoDevelopers (3 membri)
    INSERT INTO Partecipazione (id_team, id_partecipante) VALUES
    (team_ids[6], part_ids[7]),
    (team_ids[6], part_ids[8]),
    (team_ids[6], part_ids[1]);

    -- Team 7: TopTechs (2 membri)
    INSERT INTO Partecipazione (id_team, id_partecipante) VALUES
    (team_ids[7], part_ids[2]),
    (team_ids[7], part_ids[3]);

    -- 8. Popolamento tabella Esaminazione
    RAISE NOTICE 'Popolamento tabella Esaminazione...';
    -- Assegnazione giudici ai documenti
    FOR i IN 1..array_length(doc_ids, 1) LOOP
        INSERT INTO Esaminazione (id_giudice, id_documento) VALUES
        (giud_ids[1], doc_ids[i]),
        (giud_ids[2], doc_ids[i]),
        (giud_ids[3], doc_ids[i]);
    END LOOP;

    -- 9. Popolamento tabella Votazione
    RAISE NOTICE 'Popolamento tabella Votazione...';
    -- Votazioni per tutti i team da tutti i giudici
    FOR i IN 1..array_length(team_ids, 1) LOOP
        FOR j IN 1..array_length(giud_ids, 1) LOOP
            INSERT INTO Votazione (id_giudice, id_team, voto) VALUES
            (giud_ids[j], team_ids[i], (floor(random() * 10 + 1))::INT);
        END LOOP;
    END LOOP;

    -- 10. Popolamento tabella Selezione
    RAISE NOTICE 'Popolamento tabella Selezione...';
    -- Selezione giudici per ogni hackathon
    FOR i IN 1..array_length(hack_ids, 1) LOOP
        FOR j IN 1..array_length(giud_ids, 1) LOOP
            INSERT INTO Selezione (id_hackathon, id_organizzatore, id_giudice) VALUES
            (hack_ids[i], org_ids[i], giud_ids[j]);
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Popolamento completato con successo!';
END;
$$;

-- Esecuzione della procedura
CALL popola_database();

-- Introduzione dei trigger, procedure e funzioni

CREATE OR REPLACE FUNCTION unique_team_name_f()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Controlla se esiste gia' un team con lo stesso nome 
    IF EXISTS (SELECT 1
               FROM Team
               WHERE nome = NEW.nome AND id_hackathon = NEW.id_hackathon)
        THEN
        RAISE EXCEPTION 'Un team con il nome "%" e'' gia'' esistente', NEW.nome;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER unique_team_name_t
    BEFORE INSERT OR UPDATE OF nome ON Team
    FOR EACH ROW
    EXECUTE FUNCTION unique_team_name_f();

CREATE OR REPLACE FUNCTION double_role_f()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    user_to_check Utente.username%TYPE;
    org_user      Utente.username%TYPE;
    judge_user    Utente.username%TYPE;

    judges_cursor CURSOR FOR (SELECT username
                              FROM Selezione NATURAL JOIN Giudice
                              WHERE id_hackathon = NEW.id_hackathon);
BEGIN
    -- Estraggo l'username
    SELECT username INTO user_to_check
    FROM Partecipante
    WHERE id_partecipante = NEW.id_partecipante;

    -- Prendo l'organizzatore
    SELECT username INTO org_user
    FROM Organizzatore NATURAL JOIN Hackathon
    WHERE id_hackathon = NEW.id_hackathon;

    -- Controllo prima se e' organizzatore
    IF org_user = user_to_check THEN
        RAISE EXCEPTION 'L''organizzatore non puo'' partecipare alla competizione';
    END IF;

    -- Con questo controllo ogni giudice
    OPEN judges_cursor;
    LOOP
        EXIT WHEN judges_cursor%NOTFOUND;
        FETCH judges_cursor INTO judge_user;
        IF judge_user = user_to_check THEN
           RAISE EXCEPTION 'Un giudice non puo'' partecipare alla competizione';
        END IF;
    END LOOP;
    CLOSE judges_cursor;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER double_role_t
    BEFORE INSERT ON Registrazione
    FOR EACH ROW
    EXECUTE FUNCTION double_role_f();

CREATE OR REPLACE FUNCTION check_complete_examination_f()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    total_docs    INT;
    examined_docs INT;
BEGIN
    -- Numero totale di documenti del team
    SELECT COUNT(id_documento) INTO total_docs
    FROM Documento
    WHERE id_team = NEW.id_team;

    -- Numero di documenti del team esaminati dal giudice
    SELECT COUNT(d.id_documento) INTO examined_docs
    FROM Documento d NATURAL JOIN Esaminazione e
    WHERE d.id_team = NEW.id_team AND e.id_giudice = NEW.id_giudice;

    -- Controllo di completezza
    IF total_docs <> examined_docs THEN
        RAISE EXCEPTION 'Non hai esaminato tutti i documenti del team';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER check_complete_examination_t
    BEFORE INSERT ON Votazione
    FOR EACH ROW
    EXECUTE FUNCTION check_complete_examination_f();

CREATE OR REPLACE FUNCTION check_unique_document_f()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_title   Documento.titolo%TYPE;
    v_content Documento.contenuto%TYPE;
    v_hack    Hackathon.id_hackathon%TYPE;
    all_docs  REFCURSOR;
BEGIN
    -- Estraggo l'hackathon di riferimento
    SELECT id_hackathon INTO v_hack
    FROM Documento NATURAL JOIN Team
    WHERE id_documento = NEW.id_documento;
    -- Cursore per i dati di tutti i documenti di quell'hackathon
    OPEN all_docs FOR (SELECT titolo, contenuto
                       FROM Documento NATURAL JOIN Team
                       WHERE id_hackathon = v_hack);
    -- Se trovo coppie uguali il vincolo e' violato
    LOOP
        EXIT WHEN all_docs%NOTFOUND;
        FETCH all_docs INTO v_title, v_content;
        IF v_title = NEW.titolo AND v_content = NEW.contenuto THEN
            RAISE EXCEPTION 'Il titolo e il commento devono essere univoci in questa competizione';
        END IF;
    END LOOP;
    
    CLOSE all_docs;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER check_unique_document_t
    BEFORE INSERT ON Documento
    FOR EACH ROW
    EXECUTE FUNCTION check_unique_document_f();

CREATE OR REPLACE PROCEDURE start_hackathon (
    IN in_hack Hackathon.id_hackathon%TYPE)
LANGUAGE plpgsql
AS $$
DECLARE
    start_date      Hackathon.data_inizio%TYPE;
    teams_threshold INT;
BEGIN
    -- Controllo se la data e' corretta
    SELECT data_inizio INTO start_date
    FROM Hackathon
    WHERE id_hackathon = in_hack;
    IF CURRENT_DATE < start_date THEN
        RAISE EXCEPTION 'E'' troppo presto!';
    ELSIF CURRENT_DATE > start_date THEN
        CALL delete_hackathon(in_hack);
        RAISE EXCEPTION 'Hai avviato troppo tardi!';
    END IF;
    -- Controllo se ci sono almeno 2 team (vincolo [9])
    SELECT COUNT(id_team) INTO teams_threshold
    FROM Hackathon NATURAL JOIN Team
    WHERE id_hackathon = in_hack;
    IF teams_threshold < 2 THEN
        CALL delete_hackathon(in_hack);
        RAISE EXCEPTION 'Non ci sono abbastanza Team iscritti.';
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE authenticate (
    IN in_hack     Hackathon.id_hackathon%TYPE,
    IN in_username Utente.username%TYPE,
    OUT o_role     INT,
    OUT o_id       INT)
LANGUAGE plpgsql
AS $$
BEGIN
    o_role := 0;
    o_id := 0;
    -- ^ Valori di default
    SELECT id_giudice INTO o_id
    FROM Selezione NATURAL JOIN Giudice
    WHERE id_hackathon = in_hack AND username = in_username;
    IF FOUND THEN
        o_role := 1;
    END IF;
    IF o_id IS NULL THEN
        SELECT id_organizzatore INTO o_id
        FROM Hackathon NATURAL JOIN Organizzatore
        WHERE id_hackathon = in_hack AND username = in_username;
        IF FOUND THEN
            o_role := 2;
        END IF;
    END IF;
    IF o_id IS NULL THEN
        SELECT id_partecipante INTO o_id
        FROM Registrazione NATURAL JOIN Partecipante
        WHERE id_hackathon = in_hack AND username = in_username;
        IF FOUND THEN
            o_role := 3;
        END IF;
    END IF;
    IF o_role = 0 THEN
        RAISE EXCEPTION 'Non fai parte di questa competizione.';
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE new_user (
    IN v_username Utente.username%TYPE,
    IN v_nome     Utente.nome%TYPE,
    IN v_cognome  Utente.cognome%TYPE,
    IN v_password Utente.password%TYPE)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO Utente VALUES (v_username, v_nome, v_cognome, v_password);
EXCEPTION
    WHEN unique_violation THEN -- Propago l'errore con un messaggio esplicativo
        RAISE EXCEPTION 'Questo nome utente non e'' disponibile';
END;
$$;

CREATE OR REPLACE PROCEDURE subscribe (
    IN in_hack     Hackathon.id_hackathon%TYPE,
    IN in_username Utente.username%TYPE)
LANGUAGE plpgsql
AS $$
DECLARE
    start_sub_date     Hackathon.data_apertura_iscrizioni%TYPE;
    end_sub_date       Hackathon.data_chiusura_iscrizioni%TYPE;
    in_id_partecipante Partecipante.id_partecipante%TYPE;
    max_subs           Hackathon.max_iscritti%TYPE;
    actual_subs        INT;
    new_team           Team.id_team%TYPE;
    name               Team.nome%TYPE;
BEGIN
    -- Verifico che la data attuale sia coerente con le date da rispettare
    SELECT data_apertura_iscrizioni INTO start_sub_date
    FROM Hackathon
    WHERE id_hackathon = in_hack;
    IF CURRENT_DATE < start_date THEN
       RAISE EXCEPTION 'Non e'' ancora possibile iscriversi a questo hackathon';
    END IF;
    SELECT data_chiusura_iscrizioni INTO end_sub_date
    FROM Hackathon
    WHERE id_hackathon = in_hack;
    IF CURRENT_DATE > end_sub_date THEN
        RAISE EXCEPTION 'Non e'' piu'' possibile iscriversi a questo hackathon';
    END IF;
    
    -- Verifico che il partecipante esista
    SELECT id_partecipante INTO in_id_partecipante
    FROM Partecipante
    WHERE username = in_username;
    IF NOT FOUND THEN
        INSERT INTO Partecipante (username) VALUES (in_username) RETURNING id_partecipante INTO in_id_partecipante;
    END IF;

    -- Verifico che il partecipante non sia gia' registrato
    SELECT 1
    FROM Registrazione
    WHERE id_partecipante = in_id_partecipante AND id_hackathon = in_hack;
    IF FOUND THEN
        RAISE EXCEPTION 'Sei gia'' iscritto a questo hackathon';
    END IF;

    -- Verifico che sia possibile iscriversi entro i limiti predefiniti
    SELECT max_iscritti INTO max_subs
    FROM Hackathon
    WHERE id_hackathon = in_hack;
    SELECT COUNT(*) INTO actual_subs
    FROM Registrazione
    WHERE id_hackathon = in_hack;
    IF (actual_subs+1) > max_subs THEN
        RAISE EXCEPTION 'Il limite massimo di iscrizioni e'' stato raggiunto';
    END IF;


    -- Inserisco la registrazione e il relativo team di default
    INSERT INTO Registrazione VALUES(in_id_partecipante, in_hack, CURRENT_DATE);
    name := FORMAT('Team di %L', in_username);
    INSERT INTO Team (nome, numero_membri, id_hackathon)
        VALUES (name, 1, in_hack) RETURNING id_team INTO new_team;
    INSERT INTO Partecipazione VALUES (new_team, in_id_partecipante);
END;
$$;

CREATE OR REPLACE FUNCTION end_hackathon(
    in_hack Hackathon.id_hackathon%TYPE)
RETURNS refcursor
LANGUAGE plpgsql
AS $$
DECLARE
    winners    REFCURSOR;
    all_judges CURSOR FOR (SELECT id_giudice
                           FROM Selezione
                           WHERE id_hackathon = in_hack);
    one_judge  Giudice.id_giudice%TYPE;
    all_teams  CURSOR FOR (SELECT id_team
                           FROM Team
                           WHERE id_hackathon = in_hack);
    one_team   Team.id_team%TYPE;
BEGIN
    OPEN all_judges;
    OPEN all_teams;
    LOOP -- Controllo che siano presenti tutte le votazioni necessarie
        EXIT WHEN all_judges%NOTFOUND;
        FETCH all_judges INTO one_judge;
        LOOP
            EXIT WHEN all_teams%NOTFOUND;
            FETCH all_teams INTO one_team;
            CALL check_complete_grading(one_judge, one_team);            
        END LOOP;
    END LOOP;
    -- Produco la classifica finale
    SELECT scoreboard (in_hack) INTO winners;    
    CLOSE all_judges;
    CLOSE all_teams;
    RETURN winners;
END;
$$;

CREATE OR REPLACE PROCEDURE delete_hackathon (
    IN id_hack_to_del Hackathon.id_hackathon%TYPE)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM Hackathon WHERE id_hackathon = id_hack_to_del;
END;
$$;

CREATE OR REPLACE PROCEDURE atleast_1_progress (
    IN in_hack Hackathon.id_hackathon%TYPE)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Cursore per tutti i team dell'hackathon interessato
    teams_cursor  CURSOR FOR (SELECT id_team
                              FROM Team
                              WHERE id_hackathon = in_hack);
    current_team  Team.id_team%TYPE;
    all_judges    REFCURSOR;
    current_judge Giudice.id_giudice%TYPE;
BEGIN
    OPEN teams_cursor;
    -- Controllo se tutti i team hanno almeno un documento pubblicato
    LOOP
        EXIT WHEN teams_cursor%NOTFOUND;
        FETCH teams_cursor INTO current_team;
        IF current_team NOT IN (SELECT id_team
                                FROM Documento) THEN
            -- Se non c'e' nemmeno un documento allora la votazione e' automaticamente pari a 0
            OPEN all_judges FOR (SELECT id_giudice
                                 FROM Selezione
                                 WHERE id_hackathon = in_hack);
            LOOP
                EXIT WHEN all_judges%NOTFOUND;
                FETCH all_judges INTO current_judge;
                INSERT INTO Votazione VALUES (current_judge, current_team, 0);
            END LOOP;
            CLOSE all_judges;
        END IF;
    END LOOP;
    CLOSE teams_cursor;
END;
$$;

CREATE OR REPLACE PROCEDURE publish_problem (
    in_id_hackathon Hackathon.id_hackathon%TYPE,
    in_descrizione  Hackathon.descrizione_problema%TYPE)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Aggiorna la descrizione del problema
    UPDATE Hackathon
    SET descrizione_problema = in_descrizione
    WHERE id_hackathon = in_id_hackathon;
END;
$$;

CREATE OR REPLACE PROCEDURE join_team (
    IN in_username Partecipante.username%TYPE,
    IN in_id_team  Team.id_team%TYPE)
LANGUAGE plpgsql
AS $$
DECLARE
    in_id_partecipante Partecipante.id_partecipante%TYPE;
    already_member     INT;
    max_members        Hackathon.max_dim_team%TYPE;
    actual_members     Team.numero_membri%TYPE;
    old_members        Team.numero_membri%TYPE;
    old_team           Team.id_team%TYPE;
    v_hack             Hackathon.id_hackathon%TYPE;
    start_date         Hackathon.data_inizio%TYPE;
BEGIN
    -- Verifica che l'utente esista e sia partecipante
    SELECT id_partecipante INTO in_id_partecipante
    FROM Partecipante
    WHERE username = in_username;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Partecipante "%" non trovato', in_username;
    END IF;

    -- Verifica che non sia troppo tardi per cambiare team
    SELECT id_hackathon INTO v_hack
    FROM Team
    WHERE id_team = in_id_team;
    SELECT data_inizio INTO start_date
    FROM Hackathon
    WHERE id_hackathon = v_hack;
    IF start_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'E'' troppo tardi per cambiare team!';
    END IF;

    -- Verifica che il partecipante non sia gia' nel team
    SELECT COUNT(*) INTO already_member
    FROM Partecipazione
    WHERE id_team = in_id_team AND id_partecipante = in_id_partecipante;
    IF already_member > 0 THEN
        RAISE EXCEPTION 'Partecipante "%" e'' gia'' membro del team %', in_username, in_id_team;
    END IF;

    -- Verifica che il team non sia gia' alla capienza massima
    SELECT max_dim_team INTO max_members
    FROM Hackathon NATURAL JOIN Team
    WHERE id_team = in_id_team;
    SELECT numero_membri INTO actual_members
    FROM Team
    WHERE id_team = in_id_team;
    IF (actual_members+1) > max_members THEN
        RAISE EXCEPTION 'Il team ha gia'' raggiunto la dimensione massima concessa';
    END IF;
    -- Gestisco il vecchio team prima di inserire il nuovo record
    SELECT id_team INTO old_team
    FROM Partecipazione NATURAL JOIN Team
    WHERE id_partecipante = in_id_partecipante AND id_hackathon = v_hack;
    SELECT numero_membri INTO old_members
    FROM Team
    WHERE id_team = old_team;
    IF old_members-1 = 0 THEN
        DELETE FROM Team WHERE id_team = old_team;
    ELSE
        UPDATE Team SET numero_membri = (numero_membri-1) WHERE id_team = old_team;
        DELETE FROM Partecipazione WHERE id_partecipante = in_id_partecipante AND id_team = old_team;
    END IF;
    
    -- Inserisce la partecipazione e incrementa il contatore
    INSERT INTO Partecipazione(id_team, id_partecipante) VALUES (in_id_team, in_id_partecipante);
    UPDATE Team SET numero_membri = numero_membri+1 WHERE id_team = in_id_team;
END;
$$;

CREATE OR REPLACE PROCEDURE grade_team(
    in_id_giudice Giudice.id_giudice%TYPE,
    in_id_team    Team.id_team%TYPE,
    in_voto       INT)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO Votazione VALUES (in_id_giudice, in_id_team, in_voto);
END;
$$;

CREATE OR REPLACE PROCEDURE check_complete_grading(
    in_id_giudice Giudice.id_giudice%TYPE,
    in_id_team    Team.id_team%TYPE)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Controlla se il giudice ha gia' votato il team
    IF NOT EXISTS (SELECT 1
                   FROM Votazione
                   WHERE id_giudice = in_id_giudice
                      AND id_team = in_id_team)
        THEN
        -- Inserisce voto predefinito = 6 se il giudice non ha votato il team
        INSERT INTO Votazione(id_giudice, id_team, voto) VALUES (in_id_giudice, in_id_team, 6);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION scoreboard (
    IN in_hack Hackathon.id_hackathon%TYPE)
RETURNS refcursor
LANGUAGE plpgsql
AS $$
DECLARE
    winners REFCURSOR;
BEGIN
    -- Estraggo dalla classifica globale i team dell'hackathon di riferimento
    OPEN winners for (SELECT nome_team, voto_finale
                      FROM overall_ranking
                      WHERE id_hackathon = in_hack);
    RETURN winners;
END;
$$;

CREATE OR REPLACE PROCEDURE invite_judge(
    IN in_username Utente.username%TYPE,
    IN in_hack     Hackathon.id_hackathon%TYPE,
    IN in_org      Organizzatore.id_organizzatore%TYPE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_judge Giudice.id_giudice%TYPE;
BEGIN
    SELECT id_giudice INTO v_judge
    FROM Giudice
    WHERE username = in_username;
    IF NOT FOUND THEN -- Verifico l'esistenza del giudice
        INSERT INTO Giudice (username) VALUES (in_username) RETURNING id_giudice INTO v_judge;
    END IF;
    INSERT INTO Selezione VALUES (in_hack, in_org, v_judge);
END;
$$;

CREATE OR REPLACE PROCEDURE publish_progress (
    IN in_team    Team.id_team%TYPE,
    IN in_content Documento.contenuto%TYPE,
    IN in_title   Documento.titolo%TYPE)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Inserisco il documento con i relativi dati
    INSERT INTO Documento (contenuto, titolo, id_team) VALUES (in_content, in_title, in_team);
END;
$$;

CREATE OR REPLACE PROCEDURE add_hackathon (
    IN v_title         Hackathon.titolo%TYPE,
    IN v_location      Hackathon.sede%TYPE,
    IN v_start_d       Hackathon.data_inizio%TYPE,
    IN v_end_d         Hackathon.data_fine%TYPE,
    IN v_start_sub     Hackathon.data_apertura_iscrizioni%TYPE,
    IN v_end_sub       Hackathon.data_chiusura_iscrizioni%TYPE,
    IN v_max_sub       Hackathon.max_iscritti%TYPE,
    IN v_max_team_size Hackathon.max_dim_team%TYPE,
    IN v_username      Utente.username%TYPE,
    IN v_judges        TEXT)
        -- ^ Testo formattato come 'mario.rossi,luca.bianchi,'
LANGUAGE plpgsql
AS $$
DECLARE
    duration  INT;
    v_org     Organizzatore.id_organizzatore%TYPE;
    v_hack    Hackathon.id_hackathon%TYPE;
    pos       INT;
    one_judge Utente.username%TYPE;
BEGIN
    -- Calcolo la durata
    duration := v_end_d - v_start_d;

    -- Verifico l'esistenza dell'organizzatore
    SELECT id_organizzatore INTO v_org
    FROM Organizzatore
    WHERE username = v_username;
    IF NOT FOUND THEN
        INSERT INTO organizzatore (username) VALUES (v_username) RETURNING id_organizzatore INTO v_org;
    END IF;

    -- Creo l'hackathon
    INSERT INTO Hackathon (
        titolo, sede, durata, data_inizio, data_fine,
        data_apertura_iscrizioni, data_chiusura_iscrizioni,
        max_iscritti, max_dim_team, id_organizzatore)
        VALUES (v_title, v_location, duration, v_start_d, v_end_d,
            v_start_sub, v_end_sub, v_max_sub, v_max_team_size, v_org)
        RETURNING id_hackathon INTO v_hack;

    -- Inserisco le relative selezioni dei giudici
    LOOP
        pos := INSTR(v_judges, ',');
        EXIT WHEN pos <= 0;
        one_judge := SUBSTR(v_judges, 1, pos-1);
        v_judges := LTRIM(v_judges, one_judge);
        v_judges := LTRIM(v_judges, ',');
        CALL invite_judge(one_judge, v_hack, v_org);
    END LOOP;
    
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'In questa sede si e'' gia'' svolto un hackathon con questo nome';
END;
$$;

CREATE OR REPLACE PROCEDURE delete_user (
    IN username_to_del Utente.username%TYPE)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica se l'utente esiste
    IF NOT EXISTS (SELECT 1
                   FROM Utente
                   WHERE username = username_to_del)
        THEN
        RAISE EXCEPTION 'Utente "%" non trovato', username_to_del;
    END IF;
    -- Elimina solo l'utente (eventuali vincoli ON DELETE CASCADE gestiranno le dipendenze se definiti sul DB)
    DELETE FROM Utente WHERE username = username_to_del;
END;
$$;

CREATE OR REPLACE VIEW overall_ranking AS
    SELECT nome AS nome_team, ROUND(AVG(voto), 2) AS voto_finale, id_hackathon
    FROM Votazione NATURAL JOIN Team
    GROUP BY nome_team, id_hackathon
    ORDER BY voto_finale DESC;