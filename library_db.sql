-- Library Management System Database
-- Created by [Your Name]
-- Date: [Current Date]

-- Drop database if it exists (for testing)
DROP DATABASE IF EXISTS library_management;
CREATE DATABASE library_management;
USE library_management;

-- Members table - stores library members
CREATE TABLE members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    join_date DATE NOT NULL,
    membership_expiry DATE NOT NULL,
    CONSTRAINT chk_expiry CHECK (membership_expiry > join_date)
) ENGINE=InnoDB;

-- Authors table - stores book authors
CREATE TABLE authors (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_year YEAR,
    nationality VARCHAR(50),
    biography TEXT
) ENGINE=InnoDB;

-- Publishers table - stores book publishers
CREATE TABLE publishers (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address TEXT,
    contact_email VARCHAR(100),
    website VARCHAR(100)
) ENGINE=InnoDB;

-- Books table - stores book information
CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    isbn VARCHAR(20) UNIQUE NOT NULL,
    publisher_id INT,
    publication_year YEAR,
    edition INT DEFAULT 1,
    category VARCHAR(50),
    total_copies INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1,
    shelf_location VARCHAR(20),
    FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id) ON DELETE SET NULL,
    CONSTRAINT chk_copies CHECK (available_copies <= total_copies AND total_copies >= 0)
) ENGINE=InnoDB;

-- Book-Author relationship (many-to-many)
CREATE TABLE book_authors (
    book_id INT NOT NULL,
    author_id INT NOT NULL,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Loans table - tracks book loans
CREATE TABLE loans (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    member_id INT NOT NULL,
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    status ENUM('active', 'returned', 'overdue') NOT NULL DEFAULT 'active',
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
    CONSTRAINT chk_due_date CHECK (due_date > loan_date),
    CONSTRAINT chk_return_date CHECK (return_date IS NULL OR return_date >= loan_date)
) ENGINE=InnoDB;

-- Fines table - tracks overdue fines
CREATE TABLE fines (
    fine_id INT AUTO_INCREMENT PRIMARY KEY,
    loan_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    issue_date DATE NOT NULL,
    payment_date DATE,
    status ENUM('pending', 'paid') NOT NULL DEFAULT 'pending',
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Staff table - library staff members
CREATE TABLE staff (
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    position VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    salary DECIMAL(10,2)
) ENGINE=InnoDB;

-- Create indexes for performance
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_members_name ON members(last_name, first_name);
CREATE INDEX idx_loans_dates ON loans(loan_date, due_date, return_date);
CREATE INDEX idx_fines_status ON fines(status);

-- Create a view for currently available books
CREATE VIEW available_books AS
SELECT b.book_id, b.title, b.isbn, GROUP_CONCAT(CONCAT(a.first_name, ' ', a.last_name) SEPARATOR ', ') AS authors, 
       b.available_copies, b.shelf_location
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id
LEFT JOIN authors a ON ba.author_id = a.author_id
WHERE b.available_copies > 0
GROUP BY b.book_id;

-- Create a view for overdue loans
CREATE VIEW overdue_loans AS
SELECT l.loan_id, m.member_id, CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       b.book_id, b.title, l.loan_date, l.due_date, DATEDIFF(CURRENT_DATE, l.due_date) AS days_overdue
FROM loans l
JOIN members m ON l.member_id = m.member_id
JOIN books b ON l.book_id = b.book_id
WHERE l.status = 'active' AND l.due_date < CURRENT_DATE;

-- Create a trigger to update available copies when a book is loaned
DELIMITER //
CREATE TRIGGER after_loan_insert
AFTER INSERT ON loans
FOR EACH ROW
BEGIN
    UPDATE books 
    SET available_copies = available_copies - 1 
    WHERE book_id = NEW.book_id;
END//
DELIMITER ;

-- Create a trigger to update available copies when a book is returned
DELIMITER //
CREATE TRIGGER after_loan_update
AFTER UPDATE ON loans
FOR EACH ROW
BEGIN
    IF NEW.return_date IS NOT NULL AND OLD.return_date IS NULL THEN
        UPDATE books 
        SET available_copies = available_copies + 1 
        WHERE book_id = NEW.book_id;
    END IF;
END//
DELIMITER ;
